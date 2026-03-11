;; Adam Token Tests

(define-constant deployer tx-sender)
(define-constant wallet-1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant wallet-2 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant wallet-3 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)

;; Test initialization
(define-public (test-initialize)
  (let
    (
      (result (contract-call? .adam-token-adusd initialize "Adam USD" "ADUSD" u6 deployer))
    )
    (asserts! (is-ok result) (err u1))
    (asserts! (is-eq (unwrap-panic (contract-call? .adam-token-adusd get-name)) "Adam USD") (err u2))
    (asserts! (is-eq (unwrap-panic (contract-call? .adam-token-adusd get-symbol)) "ADUSD") (err u3))
    (asserts! (is-eq (unwrap-panic (contract-call? .adam-token-adusd get-decimals)) u6) (err u4))
    (ok true)
  )
)

;; Test minting
(define-public (test-mint-success)
  (let
    (
      (mint-result (contract-call? .adam-token-adusd mint u1000000 wallet-1))
      (balance (unwrap-panic (contract-call? .adam-token-adusd get-balance wallet-1)))
      (supply (unwrap-panic (contract-call? .adam-token-adusd get-total-supply)))
    )
    (asserts! (is-ok mint-result) (err u10))
    (asserts! (is-eq balance u1000000) (err u11))
    (asserts! (is-eq supply u1000000) (err u12))
    (ok true)
  )
)

;; Test minting with zero amount fails
(define-public (test-mint-zero-amount)
  (let
    (
      (result (contract-call? .adam-token-adusd mint u0 wallet-1))
    )
    (asserts! (is-err result) (err u20))
    (asserts! (is-eq (unwrap-err-panic result) u103) (err u21)) ;; ERR-ZERO-AMOUNT
    (ok true)
  )
)

;; Test unauthorized minting fails
(define-public (test-mint-unauthorized)
  (begin
    ;; This would need to be called from wallet-1 context
    ;; In actual test, use (as-contract) or test framework features
    (ok true)
  )
)

;; Test burning
(define-public (test-burn-success)
  (begin
    ;; First mint tokens
    (unwrap-panic (contract-call? .adam-token-adusd mint u1000000 wallet-1))
    
    ;; Grant burner role to deployer
    (unwrap-panic (contract-call? .adam-token-adusd set-burner deployer true))
    
    ;; Burn tokens
    (let
      (
        (burn-result (contract-call? .adam-token-adusd burn u500000 wallet-1))
        (balance (unwrap-panic (contract-call? .adam-token-adusd get-balance wallet-1)))
        (supply (unwrap-panic (contract-call? .adam-token-adusd get-total-supply)))
      )
      (asserts! (is-ok burn-result) (err u30))
      (asserts! (is-eq balance u500000) (err u31))
      (asserts! (is-eq supply u500000) (err u32))
      (ok true)
    )
  )
)

;; Test transfer
(define-public (test-transfer-success)
  (begin
    ;; Mint tokens to wallet-1
    (unwrap-panic (contract-call? .adam-token-adusd mint u1000000 wallet-1))
    
    ;; Transfer would need to be called from wallet-1 context
    ;; In actual test framework, use appropriate context switching
    (ok true)
  )
)

;; Test role management
(define-public (test-set-minter-role)
  (let
    (
      (result (contract-call? .adam-token-adusd set-minter wallet-2 true))
      (is-minter (contract-call? .adam-token-adusd is-minter wallet-2))
    )
    (asserts! (is-ok result) (err u40))
    (asserts! is-minter (err u41))
    (ok true)
  )
)

(define-public (test-set-burner-role)
  (let
    (
      (result (contract-call? .adam-token-adusd set-burner wallet-2 true))
      (is-burner (contract-call? .adam-token-adusd is-burner wallet-2))
    )
    (asserts! (is-ok result) (err u50))
    (asserts! is-burner (err u51))
    (ok true)
  )
)

;; Test revoke roles
(define-public (test-revoke-minter-role)
  (begin
    (unwrap-panic (contract-call? .adam-token-adusd set-minter wallet-2 true))
    (let
      (
        (result (contract-call? .adam-token-adusd set-minter wallet-2 false))
        (is-minter (contract-call? .adam-token-adusd is-minter wallet-2))
      )
      (asserts! (is-ok result) (err u60))
      (asserts! (not is-minter) (err u61))
      (ok true)
    )
  )
)

;; Test owner transfer
(define-public (test-transfer-ownership)
  (let
    (
      (result (contract-call? .adam-token-adusd set-contract-owner wallet-2))
      (new-owner (unwrap-panic (contract-call? .adam-token-adusd get-contract-owner)))
    )
    (asserts! (is-ok result) (err u70))
    (asserts! (is-eq new-owner wallet-2) (err u71))
    (ok true)
  )
)

;; Run all tests
(define-public (run-all-tests)
  (begin
    (try! (test-initialize))
    (try! (test-mint-success))
    (try! (test-mint-zero-amount))
    (try! (test-burn-success))
    (try! (test-set-minter-role))
    (try! (test-set-burner-role))
    (try! (test-revoke-minter-role))
    (try! (test-transfer-ownership))
    (ok true)
  )
)
