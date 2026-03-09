;; Adam Swap - Simplified Version for Clarinet Validation
;; This version uses explicit contract references instead of dynamic calls
;; In production, you may want to deploy separate swap contracts per token pair

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
(define-constant RATE-PRECISION u1000000000000000000)
(define-constant MAX-FEE-BPS u1000)
(define-constant BPS-DENOMINATOR u10000)

;; Contract owner
(define-data-var contract-owner principal tx-sender)
(define-map rate-setters principal bool)

;; Fee in basis points
(define-data-var fee-bps uint u50)

;; Exchange rates
(define-map rates { from: uint, to: uint } uint)

;; Token type constants
(define-constant TOKEN-USDC u1)
(define-constant TOKEN-ADUSD u2)
(define-constant TOKEN-ADNGN u3)

;; Initialize contract
(define-public (initialize (owner principal) (initial-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= initial-fee-bps MAX-FEE-BPS) ERR-INVALID-FEE)
    (var-set contract-owner owner)
    (var-set fee-bps initial-fee-bps)
    (map-set rate-setters owner true)
    ;; Set initial rates
    (map-set rates { from: TOKEN-USDC, to: TOKEN-ADUSD } RATE-PRECISION)
    (map-set rates { from: TOKEN-ADUSD, to: TOKEN-USDC } RATE-PRECISION)
    (ok true)
  )
)

;; Buy ADUSD with USDC
(define-public (buy-adusd (amount-in uint) (commitment (buff 32)))
  (let
    (
      (caller tx-sender)
      (amount-out (try! (apply-rate-and-fee TOKEN-USDC TOKEN-ADUSD amount-in)))
    )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (try! (as-contract (contract-call? .adam-token-adusd mint amount-out caller)))
    (try! (as-contract (contract-call? .adam-pool register-commitment commitment .adam-token-adusd)))
    (print { event: "buy", commitment: commitment, token: "ADUSD", block-height: block-height })
    (ok amount-out)
  )
)

;; Buy ADNGN with USDC
(define-public (buy-adngn (amount-in uint) (commitment (buff 32)))
  (let
    (
      (caller tx-sender)
      (amount-out (try! (apply-rate-and-fee TOKEN-USDC TOKEN-ADNGN amount-in)))
    )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (try! (as-contract (contract-call? .adam-token-adngn mint amount-out caller)))
    (try! (as-contract (contract-call? .adam-pool register-commitment commitment .adam-token-adngn)))
    (print { event: "buy", commitment: commitment, token: "ADNGN", block-height: block-height })
    (ok amount-out)
  )
)

;; Sell ADUSD
(define-public (sell-adusd (amount uint) (nullifier (buff 32)) (commitment (buff 32)))
  (let ((caller tx-sender))
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (as-contract (contract-call? .adam-pool is-commitment-registered commitment)) ERR-COMMITMENT-NOT-FOUND)
    (asserts! (not (as-contract (contract-call? .adam-pool is-nullifier-spent nullifier))) ERR-NULLIFIER-SPENT)
    (try! (as-contract (contract-call? .adam-token-adusd burn amount caller)))
    (try! (as-contract (contract-call? .adam-pool spend-nullifier nullifier)))
    (print { event: "sell", nullifier: nullifier, token: "ADUSD", block-height: block-height })
    (ok true)
  )
)

;; Swap ADUSD to ADNGN
(define-public (swap-adusd-to-adngn (amount-in uint) (min-amount-out uint) (commitment (buff 32)))
  (let
    (
      (caller tx-sender)
      (amount-out (try! (apply-rate-and-fee TOKEN-ADUSD TOKEN-ADNGN amount-in)))
    )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-EXCEEDED)
    (try! (as-contract (contract-call? .adam-token-adusd burn amount-in caller)))
    (try! (as-contract (contract-call? .adam-token-adngn mint amount-out caller)))
    (try! (as-contract (contract-call? .adam-pool register-commitment commitment .adam-token-adngn)))
    (print { event: "swap", commitment: commitment, from: "ADUSD", to: "ADNGN", block-height: block-height })
    (ok amount-out)
  )
)

;; Admin functions
(define-public (set-rate (token-from uint) (token-to uint) (rate uint))
  (begin
    (asserts! (is-rate-setter tx-sender) ERR-NOT-RATE-SETTER)
    (asserts! (> rate u0) ERR-ZERO-AMOUNT)
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

(define-public (set-rate-setter (account principal) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (map-set rate-setters account enabled))
  )
)

;; Read-only functions
(define-read-only (get-rate (token-from uint) (token-to uint))
  (ok (unwrap! (map-get? rates { from: token-from, to: token-to }) ERR-RATE-NOT-SET))
)

(define-read-only (get-fee-bps)
  (ok (var-get fee-bps))
)

(define-read-only (is-rate-setter (account principal))
  (default-to false (map-get? rate-setters account))
)

;; Private functions
(define-private (apply-rate-and-fee (token-from uint) (token-to uint) (amount-in uint))
  (let
    (
      (rate (unwrap! (map-get? rates { from: token-from, to: token-to }) ERR-RATE-NOT-SET))
      (gross-out (/ (* amount-in rate) RATE-PRECISION))
      (fee (/ (* gross-out (var-get fee-bps)) BPS-DENOMINATOR))
    )
    (ok (- gross-out fee))
  )
)
