;; Adam Token - SIP-010 Fungible Token with Role-Based Access Control
;; Deployed multiple times as ADUSD, ADNGN, ADKES, ADGHS, ADZAR

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-MINTER (err u101))
(define-constant ERR-NOT-BURNER (err u102))
(define-constant ERR-ZERO-AMOUNT (err u103))
(define-constant ERR-ZERO-ADDRESS (err u104))

;; Token configuration (set during deployment)
(define-data-var token-name (string-ascii 32) "Adam Token")
(define-data-var token-symbol (string-ascii 32) "ADAM")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Role mappings
(define-map minters
  principal
  bool
)
(define-map burners
  principal
  bool
)

;; Fungible token definition
(define-fungible-token adam-token)

;; Initialize token (called once after deployment)
(define-public (initialize
    (name (string-ascii 32))
    (symbol (string-ascii 32))
    (decimals uint)
    (owner principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-decimals decimals)
    (var-set contract-owner owner)
    ;; Grant initial roles to owner
    (map-set minters owner true)
    (map-set burners owner true)
    (ok true)
  )
)

;; SIP-010 Functions

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (try! (ft-transfer? adam-token amount sender recipient))
    (match memo
      to-print (print to-print)
      0x
    )
    (ok true)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance adam-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply adam-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Custom Functions

;; Mint tokens (minter role required)
(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-minter tx-sender) ERR-NOT-MINTER)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78))
      ERR-ZERO-ADDRESS
    )
    (ft-mint? adam-token amount recipient)
  )
)

;; Burn tokens (burner role required)
(define-public (burn
    (amount uint)
    (owner principal)
  )
  (begin
    (asserts! (is-burner tx-sender) ERR-NOT-BURNER)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (ft-burn? adam-token amount owner)
  )
)

;; Role Management

(define-public (set-minter
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (map-set minters account enabled))
  )
)

(define-public (set-burner
    (account principal)
    (enabled bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (map-set burners account enabled))
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

;; Read-only role checks

(define-read-only (is-minter (account principal))
  (default-to false (map-get? minters account))
)

(define-read-only (is-burner (account principal))
  (default-to false (map-get? burners account))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)
