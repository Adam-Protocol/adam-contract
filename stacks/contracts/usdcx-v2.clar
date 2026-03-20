;; USDCX Token V3 - SIP-010 Fungible Token
;; Token identifier named "usdcx" so wallets display it correctly

;; The ft identifier name is what wallets use as the display symbol.
;; Keep it as "usdcx" regardless of the contract file version.
(define-fungible-token usdcx u1000000000000)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))

(define-data-var token-name (string-ascii 32) "USDCX")
(define-data-var token-symbol (string-ascii 10) "USDCx")
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://adam-protocol.com/usdcx"))
(define-data-var token-decimals uint u6)

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (> amount u0) err-insufficient-balance)
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) err-not-token-owner)
    (try! (ft-transfer? usdcx amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok (var-get token-name)))
(define-read-only (get-symbol) (ok (var-get token-symbol)))
(define-read-only (get-decimals) (ok (var-get token-decimals)))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance usdcx who)))
(define-read-only (get-total-supply) (ok (ft-get-supply usdcx)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-insufficient-balance)
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) err-owner-only)
    (ft-mint? usdcx amount recipient)
  )
)

(define-public (burn (amount uint))
  (begin
    (asserts! (> (ft-get-balance usdcx tx-sender) amount) err-insufficient-balance)
    (ft-burn? usdcx amount tx-sender)
  )
)
