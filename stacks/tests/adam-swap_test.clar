;; Adam Swap Tests

(define-constant deployer tx-sender)
(define-constant wallet-1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant wallet-2 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant treasury 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)

;; Mock token addresses (in real deployment, these would be actual contracts)
(define-constant usdc-mock 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdc)
(define-constant adusd-mock 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.adusd)
(define-constant adngn-mock 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.adngn)
(define-constant pool-mock 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.pool)

;; Test hashes
(define-constant commitment-1 0x1111111111111111111111111111111111111111111111111111111111111111)
(define-constant commitment-2 0x2222222222222222222222222222222222222222222222222222222222222222)
(define-constant nullifier-1 0x3333333333333333333333333333333333333333333333333333333333333333)

;; Test initialization
(define-public (test-initialize)
  (let
    (
      (result (contract-call? .adam-swap initialize 
        deployer 
        treasury 
        usdc-mock 
        adusd-mock 
        adngn-mock 
        pool-mock 
        u50 ;; 0.5% fee
      ))
    )
    (asserts! (is-ok result) (err u200))
    (asserts! (is-eq (unwrap-panic (contract-call? .adam-swap get-fee-bps)) u50) (err u201))
    (asserts! (is-eq (unwrap-panic (contract-call? .adam-swap get-usdc-address)) (some usdc-mock)) (err u202))
    (ok true)
  )
)

;; Test set rate
(define-public (test-set-rate)
  (let
    (
      ;; Set USDC -> ADNGN rate (1 USDC = 1500 NGN, assuming 6 decimals)
      (rate u1500000000000000000000) ;; 1500 * 1e18
      (result (contract-call? .adam-swap set-rate usdc-mock adngn-mock rate))
      (stored-rate (unwrap-panic (contract-call? .adam-swap get-rate usdc-mock adngn-mock)))
    )
    (asserts! (is-ok result) (err u210))
    (asserts! (is-eq stored-rate rate) (err u211))
    (ok true)
  )
)

;; Test set rate with zero fails
(define-public (test-set-rate-zero-fails)
  (let
    (
      (result (contract-call? .adam-swap set-rate usdc-mock adngn-mock u0))
    )
    (asserts! (is-err result) (err u220))
    (asserts! (is-eq (unwrap-err-panic result) u302) (err u221)) ;; ERR-ZERO-AMOUNT
    (ok true)
  )
)

;; Test set fee
(define-public (test-set-fee-bps)
  (let
    (
      (result (contract-call? .adam-swap set-fee-bps u100)) ;; 1%
      (new-fee (unwrap-panic (contract-call? .adam-swap get-fee-bps)))
    )
    (asserts! (is-ok result) (err u230))
    (asserts! (is-eq new-fee u100) (err u231))
    (ok true)
  )
)

;; Test set fee above max fails
(define-public (test-set-fee-above-max-fails)
  (let
    (
      (result (contract-call? .adam-swap set-fee-bps u1001)) ;; > 10%
    )
    (asserts! (is-err result) (err u240))
    (asserts! (is-eq (unwrap-err-panic result) u308) (err u241)) ;; ERR-INVALID-FEE
    (ok true)
  )
)

;; Test rate setter role
(define-public (test-set-rate-setter-role)
  (let
    (
      (result (contract-call? .adam-swap set-rate-setter wallet-1 true))
      (is-setter (contract-call? .adam-swap is-rate-setter wallet-1))
    )
    (asserts! (is-ok result) (err u250))
    (asserts! is-setter (err u251))
    (ok true)
  )
)

;; Test get rate for non-existent pair fails
(define-public (test-get-rate-not-set)
  (let
    (
      (result (contract-call? .adam-swap get-rate wallet-1 wallet-2))
    )
    (asserts! (is-err result) (err u260))
    (asserts! (is-eq (unwrap-err-panic result) u304) (err u261)) ;; ERR-RATE-NOT-SET
    (ok true)
  )
)

;; Test set token addresses
(define-public (test-set-token-addresses)
  (let
    (
      (adkes-addr 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.adkes)
      (result (contract-call? .adam-swap set-adkes-address adkes-addr))
      (stored (unwrap-panic (contract-call? .adam-swap get-adkes-address)))
    )
    (asserts! (is-ok result) (err u270))
    (asserts! (is-eq stored (some adkes-addr)) (err u271))
    (ok true)
  )
)

;; Test buy function (integration test - would need actual token contracts)
(define-public (test-buy-integration)
  (begin
    ;; This would require:
    ;; 1. Deployed USDC mock contract
    ;; 2. Deployed ADUSD token contract
    ;; 3. Deployed pool contract
    ;; 4. Proper role setup
    ;; 5. USDC balance for caller
    (ok true)
  )
)

;; Test sell function (integration test)
(define-public (test-sell-integration)
  (begin
    ;; This would require:
    ;; 1. Deployed ADUSD token contract
    ;; 2. Deployed pool contract with registered commitment
    ;; 3. ADUSD balance for caller
    ;; 4. Valid nullifier
    (ok true)
  )
)

;; Test swap function (integration test)
(define-public (test-swap-integration)
  (begin
    ;; This would require:
    ;; 1. Deployed ADUSD and ADNGN token contracts
    ;; 2. Deployed pool contract
    ;; 3. Set exchange rate
    ;; 4. ADUSD balance for caller
    (ok true)
  )
)

;; Test transfer ownership
(define-public (test-transfer-ownership)
  (let
    (
      (result (contract-call? .adam-swap set-contract-owner wallet-2))
      (new-owner (unwrap-panic (contract-call? .adam-swap get-contract-owner)))
    )
    (asserts! (is-ok result) (err u280))
    (asserts! (is-eq new-owner wallet-2) (err u281))
    (ok true)
  )
)

;; Run all tests
(define-public (run-all-tests)
  (begin
    (try! (test-initialize))
    (try! (test-set-rate))
    (try! (test-set-rate-zero-fails))
    (try! (test-set-fee-bps))
    (try! (test-set-fee-above-max-fails))
    (try! (test-set-rate-setter-role))
    (try! (test-get-rate-not-set))
    (try! (test-set-token-addresses))
    (try! (test-transfer-ownership))
    (ok true)
  )
)
