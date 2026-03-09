;; Adam Pool - Nullifier Registry for Double-Spend Prevention
;; Tracks commitments and spent nullifiers for privacy-preserving transactions

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-NOT-SWAP-CONTRACT (err u201))
(define-constant ERR-COMMITMENT-EXISTS (err u202))
(define-constant ERR-NULLIFIER-SPENT (err u203))
(define-constant ERR-ZERO-ADDRESS (err u205))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Authorized swap contract
(define-data-var swap-contract (optional principal) none)

;; Commitment registry - maps commitment hash to registration status
(define-map commitments
    (buff 32)
    {
        registered: bool,
        token: principal,
        timestamp: uint,
    }
)

;; Nullifier registry - maps nullifier hash to spent status
(define-map nullifiers
    (buff 32)
    {
        spent: bool,
        timestamp: uint,
    }
)

;; Register a new commitment (only callable by swap contract)
(define-public (register-commitment
        (commitment (buff 32))
        (token principal)
    )
    (let ((existing (map-get? commitments commitment)))
        (asserts! (is-swap-contract tx-sender) ERR-NOT-SWAP-CONTRACT)
        (asserts! (is-none existing) ERR-COMMITMENT-EXISTS)
        (ok (map-set commitments commitment {
            registered: true,
            token: token,
            timestamp: block-height,
        }))
    )
)

;; Mark a nullifier as spent (only callable by swap contract)
(define-public (spend-nullifier (nullifier (buff 32)))
    (let ((existing (map-get? nullifiers nullifier)))
        (asserts! (is-swap-contract tx-sender) ERR-NOT-SWAP-CONTRACT)
        (asserts! (is-none existing) ERR-NULLIFIER-SPENT)
        (ok (map-set nullifiers nullifier {
            spent: true,
            timestamp: block-height,
        }))
    )
)

;; Set the authorized swap contract (only owner)
(define-public (set-swap-contract (new-swap-contract principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq new-swap-contract 'SP000000000000000000002Q6VF78))
            ERR-ZERO-ADDRESS
        )
        (ok (var-set swap-contract (some new-swap-contract)))
    )
)

;; Transfer ownership
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

;; Read-only functions

(define-read-only (is-commitment-registered (commitment (buff 32)))
    (match (map-get? commitments commitment)
        entry (get registered entry)
        false
    )
)

(define-read-only (is-nullifier-spent (nullifier (buff 32)))
    (match (map-get? nullifiers nullifier)
        entry (get spent entry)
        false
    )
)

(define-read-only (get-commitment-info (commitment (buff 32)))
    (ok (map-get? commitments commitment))
)

(define-read-only (get-nullifier-info (nullifier (buff 32)))
    (ok (map-get? nullifiers nullifier))
)

(define-read-only (get-swap-contract)
    (ok (var-get swap-contract))
)

(define-read-only (get-contract-owner)
    (ok (var-get contract-owner))
)

;; Private functions

(define-private (is-swap-contract (caller principal))
    (match (var-get swap-contract)
        swap (is-eq caller swap)
        false
    )
)
