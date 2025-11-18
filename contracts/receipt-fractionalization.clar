(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-SHARES (err u201))
(define-constant ERR-RECEIPT-LOCKED (err u202))
(define-constant ERR-INSUFFICIENT-SHARES (err u203))
(define-constant ERR-NOT-FULLY-OWNED (err u204))
(define-constant ERR-ALREADY-FRACTIONALIZED (err u205))
(define-constant ERR-NOT-FRACTIONALIZED (err u206))

(define-map fractional-receipts uint {
    original-owner: principal,
    total-shares: uint,
    is-fractionalized: bool
})

(define-map share-balances {receipt-id: uint, owner: principal} uint)

(define-read-only (get-share-balance (receipt-id uint) (owner principal))
    (default-to u0 (map-get? share-balances {receipt-id: receipt-id, owner: owner}))
)

(define-read-only (get-fractional-info (receipt-id uint))
    (map-get? fractional-receipts receipt-id)
)

(define-read-only (get-total-shares (receipt-id uint))
    (match (map-get? fractional-receipts receipt-id)
        info (some (get total-shares info))
        none
    )
)

(define-public (fractionalize-receipt (receipt-id uint) (total-shares uint))
    (let ((caller-shares (get-share-balance receipt-id tx-sender)))
        (begin
            (asserts! (> total-shares u1) ERR-INVALID-SHARES)
            (asserts! (<= total-shares u10000) ERR-INVALID-SHARES)
            (asserts! (is-none (map-get? fractional-receipts receipt-id)) ERR-ALREADY-FRACTIONALIZED)
            (map-set fractional-receipts receipt-id {
                original-owner: tx-sender,
                total-shares: total-shares,
                is-fractionalized: true
            })
            (map-set share-balances {receipt-id: receipt-id, owner: tx-sender} total-shares)
            (ok total-shares)
        )
    )
)

(define-public (transfer-shares (receipt-id uint) (shares uint) (recipient principal))
    (let ((sender-balance (get-share-balance receipt-id tx-sender))
          (recipient-balance (get-share-balance receipt-id recipient))
          (frac-info (unwrap! (map-get? fractional-receipts receipt-id) ERR-NOT-FRACTIONALIZED)))
        (begin
            (asserts! (>= sender-balance shares) ERR-INSUFFICIENT-SHARES)
            (asserts! (> shares u0) ERR-INVALID-SHARES)
            (asserts! (get is-fractionalized frac-info) ERR-NOT-FRACTIONALIZED)
            (map-set share-balances {receipt-id: receipt-id, owner: tx-sender} (- sender-balance shares))
            (map-set share-balances {receipt-id: receipt-id, owner: recipient} (+ recipient-balance shares))
            (ok true)
        )
    )
)

(define-public (reconstitute-receipt (receipt-id uint))
    (let ((frac-info (unwrap! (map-get? fractional-receipts receipt-id) ERR-NOT-FRACTIONALIZED))
          (owner-shares (get-share-balance receipt-id tx-sender)))
        (begin
            (asserts! (get is-fractionalized frac-info) ERR-NOT-FRACTIONALIZED)
            (asserts! (is-eq owner-shares (get total-shares frac-info)) ERR-NOT-FULLY-OWNED)
            (map-set fractional-receipts receipt-id (merge frac-info {is-fractionalized: false}))
            (map-delete share-balances {receipt-id: receipt-id, owner: tx-sender})
            (ok true)
        )
    )
)
