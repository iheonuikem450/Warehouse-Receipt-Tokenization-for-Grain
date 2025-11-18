(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-PRICE (err u301))
(define-constant ERR-INVALID-AMOUNT (err u302))
(define-constant ERR-ORDER-NOT-FOUND (err u303))
(define-constant ERR-INSUFFICIENT-SHARES (err u304))
(define-constant ERR-NO-MATCH (err u305))

(define-data-var next-order-id uint u1)

(define-map sell-orders uint {
    seller: principal,
    receipt-id: uint,
    shares: uint,
    price-per-share: uint,
    active: bool
})

(define-map buy-orders uint {
    buyer: principal,
    receipt-id: uint,
    shares: uint,
    price-per-share: uint,
    stx-locked: uint,
    active: bool
})

(define-map user-sell-orders principal (list 50 uint))
(define-map user-buy-orders principal (list 50 uint))

(define-read-only (get-sell-order (order-id uint))
    (map-get? sell-orders order-id)
)

(define-read-only (get-buy-order (order-id uint))
    (map-get? buy-orders order-id)
)

(define-public (create-sell-order (receipt-id uint) (shares uint) (price-per-share uint))
    (let ((order-id (var-get next-order-id))
          (caller-shares (contract-call? .receipt-fractionalization get-share-balance receipt-id tx-sender))
          (user-orders (default-to (list) (map-get? user-sell-orders tx-sender))))
        (asserts! (> shares u0) ERR-INVALID-AMOUNT)
        (asserts! (> price-per-share u0) ERR-INVALID-PRICE)
        (asserts! (>= caller-shares shares) ERR-INSUFFICIENT-SHARES)
        (map-set sell-orders order-id {
            seller: tx-sender,
            receipt-id: receipt-id,
            shares: shares,
            price-per-share: price-per-share,
            active: true
        })
        (map-set user-sell-orders tx-sender (unwrap! (as-max-len? (append user-orders order-id) u50) ERR-INVALID-AMOUNT))
        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (create-buy-order (receipt-id uint) (shares uint) (price-per-share uint))
    (let ((order-id (var-get next-order-id))
          (total-cost (* shares price-per-share))
          (user-orders (default-to (list) (map-get? user-buy-orders tx-sender))))
        (asserts! (> shares u0) ERR-INVALID-AMOUNT)
        (asserts! (> price-per-share u0) ERR-INVALID-PRICE)
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        (map-set buy-orders order-id {
            buyer: tx-sender,
            receipt-id: receipt-id,
            shares: shares,
            price-per-share: price-per-share,
            stx-locked: total-cost,
            active: true
        })
        (map-set user-buy-orders tx-sender (unwrap! (as-max-len? (append user-orders order-id) u50) ERR-INVALID-AMOUNT))
        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (execute-trade (sell-order-id uint) (buy-order-id uint))
    (let ((sell-order (unwrap! (map-get? sell-orders sell-order-id) ERR-ORDER-NOT-FOUND))
          (buy-order (unwrap! (map-get? buy-orders buy-order-id) ERR-ORDER-NOT-FOUND)))
        (asserts! (get active sell-order) ERR-ORDER-NOT-FOUND)
        (asserts! (get active buy-order) ERR-ORDER-NOT-FOUND)
        (asserts! (is-eq (get receipt-id sell-order) (get receipt-id buy-order)) ERR-NO-MATCH)
        (asserts! (is-eq (get shares sell-order) (get shares buy-order)) ERR-NO-MATCH)
        (asserts! (<= (get price-per-share sell-order) (get price-per-share buy-order)) ERR-NO-MATCH)
        (try! (contract-call? .receipt-fractionalization transfer-shares 
            (get receipt-id sell-order) 
            (get shares sell-order) 
            (get buyer buy-order)))
        (try! (as-contract (stx-transfer? (get stx-locked buy-order) tx-sender (get seller sell-order))))
        (map-set sell-orders sell-order-id (merge sell-order {active: false}))
        (map-set buy-orders buy-order-id (merge buy-order {active: false}))
        (ok true)
    )
)

(define-public (cancel-sell-order (order-id uint))
    (let ((order (unwrap! (map-get? sell-orders order-id) ERR-ORDER-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get seller order)) ERR-NOT-AUTHORIZED)
        (asserts! (get active order) ERR-ORDER-NOT-FOUND)
        (map-set sell-orders order-id (merge order {active: false}))
        (ok true)
    )
)

(define-public (cancel-buy-order (order-id uint))
    (let ((order (unwrap! (map-get? buy-orders order-id) ERR-ORDER-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get buyer order)) ERR-NOT-AUTHORIZED)
        (asserts! (get active order) ERR-ORDER-NOT-FOUND)
        (try! (as-contract (stx-transfer? (get stx-locked order) tx-sender (get buyer order))))
        (map-set buy-orders order-id (merge order {active: false}))
        (ok true)
    )
)
