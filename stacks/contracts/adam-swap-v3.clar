;; Adam Swap - Production-Ready Exchange Contract
;; Handles buy/sell/swap operations without on-chain privacy features

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-NOT-RATE-SETTER (err u301))
(define-constant ERR-ZERO-AMOUNT (err u302))
(define-constant ERR-INVALID-TOKEN (err u303))
(define-constant ERR-RATE-NOT-SET (err u304))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u305))
(define-constant ERR-INVALID-FEE (err u306))
(define-constant ERR-ZERO-ADDRESS (err u307))
(define-constant ERR-PAUSED (err u308))
(define-constant ERR-RATE-LIMIT-EXCEEDED (err u309))
(define-constant ERR-SAME-ADDRESS (err u310))

;; Constants
(define-constant RATE-PRECISION u1000000) ;; 1e6 (6 decimals to match token decimals)
(define-constant MAX-FEE-BPS u1000) ;; 10%
(define-constant BPS-DENOMINATOR u10000)
(define-constant MAX-RATE-CHANGE-BPS u2000) ;; 20% max change in one update
(define-constant ZERO-ADDRESS 'SP000000000000000000002Q6VF78)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Treasury address for fee collection
(define-data-var treasury-address principal tx-sender)

;; Global pause state
(define-data-var paused bool false)

;; Role mappings
(define-map rate-setters
  principal
  bool
)

(define-map pausers
  principal
  bool
)

(define-map admins
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

;; Initialize contract
(define-public (initialize
    (owner principal)
    (treasury principal)
    (usdc principal)
    (adusd principal)
    (adngn principal)
    (adkes principal)
    (adghs principal)
    (adzar principal)
    (initial-fee-bps uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= initial-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)

    ;; Validate principals are not zero address (batch check)
    (asserts!
      (and
        (not (is-eq owner ZERO-ADDRESS))
        (not (is-eq treasury ZERO-ADDRESS))
        (not (is-eq usdc ZERO-ADDRESS))
        (not (is-eq adusd ZERO-ADDRESS))
        (not (is-eq adngn ZERO-ADDRESS))
        (not (is-eq adkes ZERO-ADDRESS))
        (not (is-eq adghs ZERO-ADDRESS))
        (not (is-eq adzar ZERO-ADDRESS))
      )
      ERR-ZERO-ADDRESS
    )

    (var-set contract-owner owner)
    (var-set treasury-address treasury)
    (var-set usdc-address (some usdc))
    (var-set adusd-address (some adusd))
    (var-set adngn-address (some adngn))
    (var-set adkes-address (some adkes))
    (var-set adghs-address (some adghs))
    (var-set adzar-address (some adzar))
    (var-set fee-bps initial-fee-bps)

    ;; Grant all roles to owner
    (map-set admins owner true)
    (map-set rate-setters owner true)
    (map-set pausers owner true)

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
(define-public (buy
    (amount-in uint)
    (token-out principal)
  )
  (let (
      (caller tx-sender)
      (token-in (unwrap! (var-get usdc-address) ERR-ZERO-ADDRESS))
      (treasury (var-get treasury-address))
    )
    ;; Validate inputs first (including untrusted token-out)
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)
    ;; Prevent same-address transfers (would cause ft-transfer? err u2)
    (asserts! (not (is-eq caller treasury)) ERR-SAME-ADDRESS)

    (let ((amount-out (try! (apply-rate-and-fee token-in token-out amount-in))))
      ;; Transfer USDC from caller to treasury using transfer-from (requires prior approval)
      (try! (contract-call? .usdcx-v3 transfer-from amount-in caller treasury))

      ;; Mint Adam tokens based on token-out
      (try! (mint-adam-token token-out amount-out caller))

      (print {
        event: "BuyExecuted",
        caller: caller,
        token-in: token-in,
        amount-in: amount-in,
        token-out: token-out,
        amount-out: amount-out,
        timestamp: block-height,
      })

      (ok amount-out)
    )
  )
)

;; Sell Adam stablecoins
(define-public (sell
    (token-in principal)
    (amount uint)
  )
  (let ((caller tx-sender))
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)

    ;; Burn tokens based on token-in
    (try! (burn-adam-token token-in amount caller))

    (print {
      event: "SellExecuted",
      caller: caller,
      token-in: token-in,
      amount: amount,
      timestamp: block-height,
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
  )
  (let ((caller tx-sender))
    ;; Validate inputs first (including untrusted token-in and token-out)
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq token-in token-out)) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)

    (let ((amount-out (try! (apply-rate-and-fee token-in token-out amount-in))))
      ;; Check slippage
      (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-EXCEEDED)

      ;; Burn input tokens
      (try! (burn-adam-token token-in amount-in caller))

      ;; Mint output tokens
      (try! (mint-adam-token token-out amount-out caller))

      (print {
        event: "SwapExecuted",
        caller: caller,
        token-in: token-in,
        amount-in: amount-in,
        token-out: token-out,
        amount-out: amount-out,
        timestamp: block-height,
      })

      (ok amount-out)
    )
  )
)

;; Admin Functions

(define-public (set-rate
    (token-from principal)
    (token-to principal)
    (rate uint)
  )
  (let ((current-rate (default-to u0
      (map-get? rates {
        from: token-from,
        to: token-to,
      })
    )))
    (asserts! (is-rate-setter tx-sender) ERR-NOT-RATE-SETTER)

    ;; Batch validations
    (asserts!
      (and
        (> rate u0)
        (not (is-eq token-from ZERO-ADDRESS))
        (not (is-eq token-to ZERO-ADDRESS))
      )
      ERR-ZERO-AMOUNT
    )

    ;; Rate change limit: max 20% change if rate already exists
    (if (> current-rate u0)
      (let (
          (diff (if (> rate current-rate)
            (- rate current-rate)
            (- current-rate rate)
          ))
          (max-change (/ (* current-rate MAX-RATE-CHANGE-BPS) BPS-DENOMINATOR))
        )
        (asserts! (<= diff max-change) ERR-RATE-LIMIT-EXCEEDED)
      )
      true
    )

    (map-set rates {
      from: token-from,
      to: token-to,
    } rate
    )

    (print {
      event: "RateUpdated",
      token-from: token-from,
      token-to: token-to,
      rate: rate,
      timestamp: block-height,
    })

    (ok true)
  )
)

(define-public (set-fee-bps (new-fee-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)
    (ok (var-set fee-bps new-fee-bps))
  )
)

(define-public (pause)
  (begin
    (asserts! (is-pauser tx-sender) ERR-UNAUTHORIZED)
    (ok (var-set paused true))
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-pauser tx-sender) ERR-UNAUTHORIZED)
    (ok (var-set paused false))
  )
)

(define-public (set-treasury-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set treasury-address address))
  )
)

(define-public (set-usdc-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set usdc-address (some address)))
  )
)

(define-public (set-adusd-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set adusd-address (some address)))
  )
)

(define-public (set-adngn-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set adngn-address (some address)))
  )
)

(define-public (set-adkes-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set adkes-address (some address)))
  )
)

(define-public (set-adghs-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set adghs-address (some address)))
  )
)

(define-public (set-adzar-address (address principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (var-set adzar-address (some address)))
  )
)

(define-public (set-admin
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq account ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (map-set admins account enabled))
  )
)

(define-public (set-rate-setter
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq account ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (map-set rate-setters account enabled))
  )
)

(define-public (set-pauser
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq account ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
    (ok (map-set pausers account enabled))
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO-ADDRESS)) ERR-ZERO-ADDRESS)
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

(define-read-only (get-treasury-address)
  (ok (var-get treasury-address))
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

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (is-admin (account principal))
  (or
    (is-eq account (var-get contract-owner))
    (default-to false (map-get? admins account))
  )
)

(define-read-only (is-rate-setter (account principal))
  (default-to false (map-get? rate-setters account))
)

(define-read-only (is-pauser (account principal))
  (default-to false (map-get? pausers account))
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

;; Helper function to mint the correct Adam token
(define-private (mint-adam-token
    (token principal)
    (amount uint)
    (recipient principal)
  )
  (if (is-eq token (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
    (as-contract (contract-call? .adam-token-adusd-v3 mint amount recipient))
    (if (is-eq token (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adngn-v3 mint amount recipient))
      (if (is-eq token (unwrap! (var-get adkes-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adkes-v3 mint amount recipient))
        (if (is-eq token (unwrap! (var-get adghs-address) ERR-INVALID-TOKEN))
          (as-contract (contract-call? .adam-token-adghs-v3 mint amount recipient))
          (if (is-eq token (unwrap! (var-get adzar-address) ERR-INVALID-TOKEN))
            (as-contract (contract-call? .adam-token-adzar-v3 mint amount recipient))
            ERR-INVALID-TOKEN
          )
        )
      )
    )
  )
)

;; Helper function to burn the correct Adam token
(define-private (burn-adam-token
    (token principal)
    (amount uint)
    (owner principal)
  )
  (if (is-eq token (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
    (as-contract (contract-call? .adam-token-adusd-v3 burn amount owner))
    (if (is-eq token (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adngn-v3 burn amount owner))
      (if (is-eq token (unwrap! (var-get adkes-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adkes-v3 burn amount owner))
        (if (is-eq token (unwrap! (var-get adghs-address) ERR-INVALID-TOKEN))
          (as-contract (contract-call? .adam-token-adghs-v3 burn amount owner))
          (if (is-eq token (unwrap! (var-get adzar-address) ERR-INVALID-TOKEN))
            (as-contract (contract-call? .adam-token-adzar-v3 burn amount owner))
            ERR-INVALID-TOKEN
          )
        )
      )
    )
  )
)
