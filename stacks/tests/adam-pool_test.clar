;; Adam Pool Tests

(define-constant deployer tx-sender)
(define-constant wallet-1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant wallet-2 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant swap-contract 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)

;; Test commitment hashes (32 bytes)
(define-constant commitment-1 0x1111111111111111111111111111111111111111111111111111111111111111)
(define-constant commitment-2 0x2222222222222222222222222222222222222222222222222222222222222222)
(define-constant nullifier-1 0x3333333333333333333333333333333333333333333333333333333333333333)
(define-constant nullifier-2 0x4444444444444444444444444444444444444444444444444444444444444444)

;; Test set swap contract
(define-public (test-set-swap-contract)
  (let
    (
      (result (contract-call? .adam-pool set-swap-contract swap-contract))
      (stored-swap (unwrap-panic (contract-call? .adam-pool get-swap-contract)))
    )
    (asserts! (is-ok result) (err u100))
    (asserts! (is-eq stored-swap (some swap-contract)) (err u101))
    (ok true)
  )
)

;; Test register commitment (would need to be called from swap contract)
(define-public (test-register-commitment-unauthorized)
  (let
    (
      ;; This should fail because we're not the swap contract
      (result (contract-call? .adam-pool register-commitment commitment-1 wallet-1))
    )
    (asserts! (is-err result) (err u110))
    (asserts! (is-eq (unwrap-err-panic result) u201) (err u111)) ;; ERR-NOT-SWAP-CONTRACT
    (ok true)
  )
)

;; Test commitment registration check
(define-public (test-is-commitment-registered)
  (let
    (
      (is-registered (contract-call? .adam-pool is-commitment-registered commitment-1))
    )
    ;; Should be false initially
    (asserts! (not is-registered) (err u120))
    (ok true)
  )
)

;; Test nullifier spent check
(define-public (test-is-nullifier-spent)
  (let
    (
      (is-spent (contract-call? .adam-pool is-nullifier-spent nullifier-1))
    )
    ;; Should be false initially
    (asserts! (not is-spent) (err u130))
    (ok true)
  )
)

;; Test duplicate commitment registration fails
(define-public (test-duplicate-commitment-fails)
  (begin
    ;; This test would need to:
    ;; 1. Set swap contract
    ;; 2. Call register-commitment from swap contract context
    ;; 3. Try to register same commitment again
    ;; 4. Verify it fails with ERR-COMMITMENT-EXISTS
    (ok true)
  )
)

;; Test duplicate nullifier spending fails
(define-public (test-duplicate-nullifier-fails)
  (begin
    ;; This test would need to:
    ;; 1. Set swap contract
    ;; 2. Call spend-nullifier from swap contract context
    ;; 3. Try to spend same nullifier again
    ;; 4. Verify it fails with ERR-NULLIFIER-SPENT
    (ok true)
  )
)

;; Test get commitment info
(define-public (test-get-commitment-info)
  (let
    (
      (info (unwrap-panic (contract-call? .adam-pool get-commitment-info commitment-1)))
    )
    ;; Should be none initially
    (asserts! (is-none info) (err u140))
    (ok true)
  )
)

;; Test get nullifier info
(define-public (test-get-nullifier-info)
  (let
    (
      (info (unwrap-panic (contract-call? .adam-pool get-nullifier-info nullifier-1)))
    )
    ;; Should be none initially
    (asserts! (is-none info) (err u150))
    (ok true)
  )
)

;; Test unauthorized set swap contract
(define-public (test-set-swap-contract-unauthorized)
  (begin
    ;; Would need to call from non-owner context
    ;; In actual test framework, use appropriate context switching
    (ok true)
  )
)

;; Test transfer ownership
(define-public (test-transfer-ownership)
  (let
    (
      (result (contract-call? .adam-pool set-contract-owner wallet-2))
      (new-owner (unwrap-panic (contract-call? .adam-pool get-contract-owner)))
    )
    (asserts! (is-ok result) (err u160))
    (asserts! (is-eq new-owner wallet-2) (err u161))
    (ok true)
  )
)

;; Run all tests
(define-public (run-all-tests)
  (begin
    (try! (test-set-swap-contract))
    (try! (test-register-commitment-unauthorized))
    (try! (test-is-commitment-registered))
    (try! (test-is-nullifier-spent))
    (try! (test-get-commitment-info))
    (try! (test-get-nullifier-info))
    (try! (test-transfer-ownership))
    (ok true)
  )
)
