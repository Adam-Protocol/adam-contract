;; Adam Swap - Core Exchange Contract
;; Handles buy/sell/swap operations with privacy-preserving commitments

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-NOT-RATE-SETTER (err u301))
(define-constant ERR-ZERO-AMOUNT (err u302))
(define-constant ERR-INVALID-TOKEN (err u303))
(define-constant ERR-RATE-NOT-SET (err u304))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u305))
(define-constant ERR-COMMITMENT-NOT-FOUND (err u306))
(define-constant ERR-NULLIFIER-SPENT (err u307))
(define-constant ERR-INVALID-FEE (err u308))
(define-constant ERR-ZERO-ADDRESS (err u309))

;; Constants
(define-constant RATE-PRECISION u1000000000000000000) ;; 1e18
(define-constant MAX-FEE-BPS u1000) ;; 10%
(define-constant BPS-DENOMINATOR u10000)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Role mappings
(define-map rate-setters
  principal
  bool
)

;; Contract addresses
(define-data-var usdc-address (optional principal) none)
(define-data-var adusd-address (optional principal) none)
(define-data-var adngn-address (optional principal) none)
(define-data-var adkes-address (optional principal) none)
(define-data-var adghs-address (optional principal) none)
(define-data-var adzar-address (optional principal) none)
(define-data-var pool-address (optional principal) none)
(define-data-var treasury-address (optional principal) none)

;; Fee in basis points (1 bp = 0.01%)
(define-data-var fee-bps uint u50) ;; 0.5% default

;; Exchange rates - maps (token-from, token-to) to rate
(define-map rates
  {
    from: principal,
    to: principal,
  }
  uint
)

;; Initialize contract (called once after deployment)
(define-public (initialize
    (owner principal)
    (treasury principal)
    (usdc principal)
    (adusd principal)
    (adngn principal)
    (pool principal)
    (initial-fee-bps uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= initial-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)

    (var-set contract-owner owner)
    (var-set treasury-address (some treasury))
    (var-set usdc-address (some usdc))
    (var-set adusd-address (some adusd))
    (var-set adngn-address (some adngn))
    (var-set pool-address (some pool))
    (var-set fee-bps initial-fee-bps)

    ;; Grant rate-setter role to owner
    (map-set rate-setters owner true)

    ;; Set initial USDC <-> ADUSD rate (1:1)
    (map-set rates {
      from: usdc,
      to: adusd,
    } RATE-PRECISION
    )
    (map-set rates {
      from: adusd,
      to: usdc,
    } RATE-PRECISION
    )

    (ok true)
  )
)

;; Buy Adam stablecoins with USDC
;; Note: In production, implement USDC transfer via contract-call
(define-public (buy
    (amount-in uint)
    (token-out principal)
    (commitment (buff 32))
  )
  (let (
      (caller tx-sender)
      (token-in (unwrap! (var-get usdc-address) ERR-ZERO-ADDRESS))
      (amount-out (try! (apply-rate-and-fee token-in token-out amount-in)))
      (pool (unwrap! (var-get pool-address) ERR-ZERO-ADDRESS))
    )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)

    ;; Mint Adam tokens to caller (swap contract acts as minter)
    ;; Use conditional logic since Clarity doesn't support dynamic contract calls
    (if (is-eq token-out (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (try! (as-contract (contract-call? .adam-token-adusd mint amount-out caller)))
      (if (is-eq token-out (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (try! (as-contract (contract-call? .adam-token-adngn mint amount-out caller)))
        ERR-INVALID-TOKEN
      )
    )

    ;; Register commitment in pool
    (try! (as-contract (contract-call? .adam-pool register-commitment commitment token-out)))

    ;; Emit event (commitment only, no amount for privacy)
    (print {
      event: "buy",
      commitment: commitment,
      token-out: token-out,
      block-height: block-height,
    })

    (ok amount-out)
  )
)

;; Sell Adam stablecoins (triggers backend offramp)
(define-public (sell
    (token-in principal)
    (amount uint)
    (nullifier (buff 32))
    (commitment (buff 32))
  )
  (let (
      (caller tx-sender)
      (pool (unwrap! (var-get pool-address) ERR-ZERO-ADDRESS))
    )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)

    ;; Verify commitment exists
    (asserts!
      (as-contract (contract-call? pool is-commitment-registered commitment))
      ERR-COMMITMENT-NOT-FOUND
    )

    ;; Verify nullifier not spent
    (asserts!
      (not (as-contract (contract-call? pool is-nullifier-spent nullifier)))
      ERR-NULLIFIER-SPENT
    )

    ;; Burn tokens using conditional logic
    (if (is-eq token-in (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (try! (as-contract (contract-call? .adam-token-adusd burn amount caller)))
      (if (is-eq token-in (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (try! (as-contract (contract-call? .adam-token-adngn burn amount caller)))
        ERR-INVALID-TOKEN
      )
    )

    ;; Mark nullifier as spent
    (try! (as-contract (contract-call? .adam-pool spend-nullifier nullifier)))

    ;; Emit event (nullifier only, no amount for privacy)
    (print {
      event: "sell",
      nullifier: nullifier,
      token-in: token-in,
      block-height: block-height,
    })

    (ok true)
  )
)

;; Swap between Adam stablecoins
(define-public (swap
    (token-in principal)
    (amount-in uint)
    (token-out principal)
    (min-amount-out uint)
    (commitment (buff 32))
  )
  (let (
      (caller tx-sender)
      (amount-out (try! (apply-rate-and-fee token-in token-out amount-in)))
      (pool (unwrap! (var-get pool-address) ERR-ZERO-ADDRESS))
    )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq token-in token-out)) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)
    (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-EXCEEDED)

    ;; Burn input tokens using conditional logic
    (if (is-eq token-in (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (try! (as-contract (contract-call? .adam-token-adusd burn amount-in caller)))
      (if (is-eq token-in (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (try! (as-contract (contract-call? .adam-token-adngn burn amount-in caller)))
        ERR-INVALID-TOKEN
      )
    )

    ;; Mint output tokens using conditional logic
    (if (is-eq token-out (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (try! (as-contract (contract-call? .adam-token-adusd mint amount-out caller)))
      (if (is-eq token-out (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (try! (as-contract (contract-call? .adam-token-adngn mint amount-out caller)))
        ERR-INVALID-TOKEN
      )
    )

    ;; Register commitment
    (try! (as-contract (contract-call? .adam-pool register-commitment commitment token-out)))

    ;; Emit event (commitment only, no amounts for privacy)
    (print {
      event: "swap",
      commitment: commitment,
      token-in: token-in,
      token-out: token-out,
      block-height: block-height,
    })

    (ok amount-out)
  )
)

;; Admin Functions

(define-public (set-rate
    (token-from principal)
    (token-to principal)
    (rate uint)
  )
  (begin
    (asserts! (is-rate-setter tx-sender) ERR-NOT-RATE-SETTER)
    (asserts! (> rate u0) ERR-ZERO-AMOUNT)
    (ok (map-set rates {
      from: token-from,
      to: token-to,
    } rate
    ))
  )
)

(define-public (set-fee-bps (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)
    (ok (var-set fee-bps new-fee-bps))
  )
)

(define-public (set-usdc-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set usdc-address (some address)))
  )
)

(define-public (set-adkes-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set adkes-address (some address)))
  )
)

(define-public (set-adghs-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set adghs-address (some address)))
  )
)

(define-public (set-adzar-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set adzar-address (some address)))
  )
)

(define-public (set-rate-setter
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (map-set rate-setters account enabled))
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

;; Read-only functions

(define-read-only (get-rate
    (token-from principal)
    (token-to principal)
  )
  (ok (unwrap! (map-get? rates {
    from: token-from,
    to: token-to,
  })
    ERR-RATE-NOT-SET
  ))
)

(define-read-only (get-fee-bps)
  (ok (var-get fee-bps))
)

(define-read-only (get-usdc-address)
  (ok (var-get usdc-address))
)

(define-read-only (get-adusd-address)
  (ok (var-get adusd-address))
)

(define-read-only (get-adngn-address)
  (ok (var-get adngn-address))
)

(define-read-only (get-adkes-address)
  (ok (var-get adkes-address))
)

(define-read-only (get-adghs-address)
  (ok (var-get adghs-address))
)

(define-read-only (get-adzar-address)
  (ok (var-get adzar-address))
)

(define-read-only (get-pool-address)
  (ok (var-get pool-address))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (is-rate-setter (account principal))
  (default-to false (map-get? rate-setters account))
)

;; Private functions

(define-private (apply-rate-and-fee
    (token-from principal)
    (token-to principal)
    (amount-in uint)
  )
  (let (
      (rate (unwrap!
        (map-get? rates {
          from: token-from,
          to: token-to,
        })
        ERR-RATE-NOT-SET
      ))
      (gross-out (/ (* amount-in rate) RATE-PRECISION))
      (fee (/ (* gross-out (var-get fee-bps)) BPS-DENOMINATOR))
    )
    (ok (- gross-out fee))
  )
)

(define-private (is-valid-adam-token (token principal))
  (or
    (is-eq (some token) (var-get adusd-address))
    (is-eq (some token) (var-get adngn-address))
    (is-eq (some token) (var-get adkes-address))
    (is-eq (some token) (var-get adghs-address))
    (is-eq (some token) (var-get adzar-address))
  )
)
