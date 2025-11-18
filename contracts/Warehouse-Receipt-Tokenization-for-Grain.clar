(define-fungible-token grain-token)
(define-non-fungible-token warehouse-receipt uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-RECEIPT-NOT-FOUND (err u104))
(define-constant ERR-WAREHOUSE-NOT-AUTHORIZED (err u105))
(define-constant ERR-INVALID-COLLATERAL-RATIO (err u106))
(define-constant ERR-LOAN-EXISTS (err u107))
(define-constant ERR-LOAN-NOT-FOUND (err u108))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u109))

(define-data-var token-name (string-ascii 32) "Grain Token")
(define-data-var token-symbol (string-ascii 10) "GRAIN")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)
(define-data-var next-receipt-id uint u1)
(define-data-var next-loan-id uint u1)

(define-map warehouse-receipts uint {
  grain-type: (string-ascii 20),
  quantity: uint,
  quality-grade: (string-ascii 10),
  warehouse: principal,
  issued-at: uint,
  expires-at: uint,
  redeemed: bool
})

(define-map authorized-warehouses principal bool)
(define-map grain-prices (string-ascii 20) uint)

(define-map loans uint {
  borrower: principal,
  collateral-receipt-id: uint,
  loan-amount: uint,
  interest-rate: uint,
  issued-at: uint,
  due-at: uint,
  repaid: bool
})

(define-map user-loans principal (list 20 uint))

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance grain-token who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply grain-token))
)

(define-read-only (get-token-uri (token-id (optional uint)))
  (ok (var-get token-uri))
)

(define-read-only (get-receipt-info (receipt-id uint))
  (map-get? warehouse-receipts receipt-id)
)

(define-read-only (get-grain-price (grain-type (string-ascii 20)))
  (default-to u0 (map-get? grain-prices grain-type))
)

(define-read-only (get-loan-info (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (is-warehouse-authorized (warehouse principal))
  (default-to false (map-get? authorized-warehouses warehouse))
)

(define-public (authorize-warehouse (warehouse principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (map-set authorized-warehouses warehouse true))
  )
)

(define-public (set-grain-price (grain-type (string-ascii 20)) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (map-set grain-prices grain-type price))
  )
)

(define-public (issue-receipt 
  (grain-type (string-ascii 20))
  (quantity uint)
  (quality-grade (string-ascii 10))
  (expires-in-blocks uint))
  (let ((receipt-id (var-get next-receipt-id))
        (current-block stacks-block-height))
    (begin
      (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
      (asserts! (is-warehouse-authorized tx-sender) ERR-WAREHOUSE-NOT-AUTHORIZED)
      (try! (nft-mint? warehouse-receipt receipt-id tx-sender))
      (map-set warehouse-receipts receipt-id {
        grain-type: grain-type,
        quantity: quantity,
        quality-grade: quality-grade,
        warehouse: tx-sender,
        issued-at: current-block,
        expires-at: (+ current-block expires-in-blocks),
        redeemed: false
      })
      (var-set next-receipt-id (+ receipt-id u1))
      (ok receipt-id)
    )
  )
)

(define-public (transfer-receipt (receipt-id uint) (recipient principal))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? warehouse-receipt receipt-id)) ERR-NOT-TOKEN-OWNER)
    (try! (nft-transfer? warehouse-receipt receipt-id tx-sender recipient))
    (ok true)
  )
)

(define-public (redeem-receipt (receipt-id uint))
  (let ((receipt-info (unwrap! (map-get? warehouse-receipts receipt-id) ERR-RECEIPT-NOT-FOUND))
        (current-block stacks-block-height))
    (begin
      (asserts! (is-eq (some tx-sender) (nft-get-owner? warehouse-receipt receipt-id)) ERR-NOT-TOKEN-OWNER)
      (asserts! (not (get redeemed receipt-info)) ERR-RECEIPT-NOT-FOUND)
      (asserts! (< current-block (get expires-at receipt-info)) ERR-RECEIPT-NOT-FOUND)
      (map-set warehouse-receipts receipt-id (merge receipt-info {redeemed: true}))
      (try! (ft-mint? grain-token (get quantity receipt-info) tx-sender))
      (ok true)
    )
  )
)

(define-public (create-loan 
  (collateral-receipt-id uint)
  (loan-amount uint)
  (interest-rate uint)
  (duration-blocks uint))
  (let ((receipt-info (unwrap! (map-get? warehouse-receipts collateral-receipt-id) ERR-RECEIPT-NOT-FOUND))
        (grain-price (get-grain-price (get grain-type receipt-info)))
        (collateral-value (* (get quantity receipt-info) grain-price))
        (loan-id (var-get next-loan-id))
        (current-block stacks-block-height)
        (existing-loans (default-to (list) (map-get? user-loans tx-sender))))
    (begin
      (asserts! (is-eq (some tx-sender) (nft-get-owner? warehouse-receipt collateral-receipt-id)) ERR-NOT-TOKEN-OWNER)
      (asserts! (not (get redeemed receipt-info)) ERR-RECEIPT-NOT-FOUND)
      (asserts! (>= (* collateral-value u2) (* loan-amount u3)) ERR-INSUFFICIENT-COLLATERAL)
      (asserts! (> loan-amount u0) ERR-INVALID-AMOUNT)
      (try! (nft-transfer? warehouse-receipt collateral-receipt-id tx-sender (as-contract tx-sender)))
      (map-set loans loan-id {
        borrower: tx-sender,
        collateral-receipt-id: collateral-receipt-id,
        loan-amount: loan-amount,
        interest-rate: interest-rate,
        issued-at: current-block,
        due-at: (+ current-block duration-blocks),
        repaid: false
      })
      (map-set user-loans tx-sender (unwrap! (as-max-len? (append existing-loans loan-id) u20) ERR-INVALID-AMOUNT))
      (try! (ft-mint? grain-token loan-amount tx-sender))
      (var-set next-loan-id (+ loan-id u1))
      (ok loan-id)
    )
  )
)

(define-public (repay-loan (loan-id uint))
  (let ((loan-info (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
        (total-repayment (+ (get loan-amount loan-info) 
                           (/ (* (get loan-amount loan-info) (get interest-rate loan-info)) u10000))))
    (begin
      (asserts! (is-eq tx-sender (get borrower loan-info)) ERR-NOT-TOKEN-OWNER)
      (asserts! (not (get repaid loan-info)) ERR-LOAN-NOT-FOUND)
      (asserts! (>= (ft-get-balance grain-token tx-sender) total-repayment) ERR-INSUFFICIENT-BALANCE)
      (try! (ft-burn? grain-token total-repayment tx-sender))
      (try! (nft-transfer? warehouse-receipt (get collateral-receipt-id loan-info) (as-contract tx-sender) tx-sender))
      (map-set loans loan-id (merge loan-info {repaid: true}))
      (ok true)
    )
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender from) (is-eq contract-caller from)) ERR-NOT-TOKEN-OWNER)
    (ft-transfer? grain-token amount from to)
  )
)
