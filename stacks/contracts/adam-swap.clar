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

;; Constants
(define-constant RATE-PRECISION u1000000000000000000) ;; 1e18
(define-constant MAX-FEE-BPS u1000) ;; 10%
(define-constant BPS-DENOMINATOR u10000)
(define-constant MAX-RATE-CHANGE-BPS u2000) ;; 20% max change in one update

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Global pause state
(define-data-var paused bool false)

;; Role mappings
(define-map rate-setters principal bool)

;; Contract addresses
(define-data-var usdc-address (optional principal) none)
(define-data-var adusd-address (optional principal) none)
(define-data-var adngn-address (optional principal) none)
(define-constant adkes-address none)
(define-constant adghs-address none)
(define-constant adzar-address none)

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
    (usdc principal)
    (adusd principal)
    (adngn principal)
    (initial-fee-bps uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= initial-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)

    (var-set contract-owner owner)
    (var-set usdc-address (some usdc))
    (var-set adusd-address (some adusd))
    (var-set adngn-address (some adngn))
    (var-set fee-bps initial-fee-bps)

    ;; Grant rate-setter role to owner
    (map-set rate-setters owner true)

    ;; Set initial USDC <-> ADUSD rate (1:1)
    (map-set rates { from: usdc, to: adusd } RATE-PRECISION)
    (map-set rates { from: adusd, to: usdc } RATE-PRECISION)

    (ok true)
  )
)

;; Buy Adam stablecoins with USDC
(define-public (buy (amount-in uint) (token-out principal))
  (let (
      (caller tx-sender)
      (token-in (unwrap! (var-get usdc-address) ERR-ZERO-ADDRESS))
      (amount-out (try! (apply-rate-and-fee token-in token-out amount-in)))
    )
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)

    ;; Mint Adam tokens periodically
    (try! (if (is-eq token-out (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adusd mint amount-out caller))
      (if (is-eq token-out (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adngn mint amount-out caller))
        ERR-INVALID-TOKEN
      )
    ))

    (print {
      event: "buy",
      caller: caller,
      token-in: token-in,
      amount-in: amount-in,
      token-out: token-out,
      amount-out: amount-out,
      block-height: block-height,
    })

    (ok amount-out)
  )
)

;; Sell Adam stablecoins
(define-public (sell (token-in principal) (amount uint))
  (let ((caller tx-sender))
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)

    ;; Burn tokens
    (try! (if (is-eq token-in (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adusd burn amount caller))
      (if (is-eq token-in (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adngn burn amount caller))
        ERR-INVALID-TOKEN
      )
    ))

    (print {
      event: "sell",
      caller: caller,
      token-in: token-in,
      amount: amount,
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
  )
  (let (
      (caller tx-sender)
      (amount-out (try! (apply-rate-and-fee token-in token-out amount-in)))
    )
    (asserts! (not (var-get paused)) ERR-PAUSED)
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq token-in token-out)) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-in) ERR-INVALID-TOKEN)
    (asserts! (is-valid-adam-token token-out) ERR-INVALID-TOKEN)
    (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-EXCEEDED)

    ;; Burn input tokens
    (try! (if (is-eq token-in (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adusd burn amount-in caller))
      (if (is-eq token-in (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adngn burn amount-in caller))
        ERR-INVALID-TOKEN
      )
    ))

    ;; Mint output tokens
    (try! (if (is-eq token-out (unwrap! (var-get adusd-address) ERR-INVALID-TOKEN))
      (as-contract (contract-call? .adam-token-adusd mint amount-out caller))
      (if (is-eq token-out (unwrap! (var-get adngn-address) ERR-INVALID-TOKEN))
        (as-contract (contract-call? .adam-token-adngn mint amount-out caller))
        ERR-INVALID-TOKEN
      )
    ))

    (print {
      event: "swap",
      caller: caller,
      token-in: token-in,
      amount-in: amount-in,
      token-out: token-out,
      amount-out: amount-out,
      block-height: block-height,
    })

    (ok amount-out)
  )
)

;; Admin Functions

(define-public (set-rate (token-from principal) (token-to principal) (rate uint))
  (let ((current-rate (default-to u0 (map-get? rates { from: token-from, to: token-to }))))
    (asserts! (is-rate-setter tx-sender) ERR-NOT-RATE-SETTER)
    (asserts! (> rate u0) ERR-ZERO-AMOUNT)
    
    ;; Rate change limit: max 20% change if rate already exists
    (if (> current-rate u0)
      (let (
          (diff (if (> rate current-rate) (- rate current-rate) (- current-rate rate)))
          (max-change (/ (* current-rate MAX-RATE-CHANGE-BPS) BPS-DENOMINATOR))
        )
        (asserts! (<= diff max-change) ERR-RATE-LIMIT-EXCEEDED)
      )
      true
    )

    (ok (map-set rates { from: token-from, to: token-to } rate))
  )
)

(define-public (set-fee-bps (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)
    (ok (var-set fee-bps new-fee-bps))
  )
)

(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set paused true))
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set paused false))
  )
)

(define-public (set-usdc-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set usdc-address (some address)))
  )
)

(define-public (set-adusd-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set adusd-address (some address)))
  )
)

(define-public (set-adngn-address (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set adngn-address (some address)))
  )
)

(define-public (set-rate-setter (account principal) (enabled bool))
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

(define-read-only (get-rate (token-from principal) (token-to principal))
  (ok (unwrap! (map-get? rates { from: token-from, to: token-to }) ERR-RATE-NOT-SET))
)

(define-read-only (get-fee-bps)
  (ok (var-get fee-bps))
)

(define-read-only (get-usdc-address)
  (ok (var-get usdc-address))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (is-rate-setter (account principal))
  (default-to false (map-get? rate-setters account))
)

;; Private functions

(define-private (apply-rate-and-fee (token-from principal) (token-to principal) (amount-in uint))
  (let (
      (rate (unwrap! (map-get? rates { from: token-from, to: token-to }) ERR-RATE-NOT-SET))
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
    (is-eq (some token) adkes-address)
    (is-eq (some token) adghs-address)
    (is-eq (some token) adzar-address)
  )
)
