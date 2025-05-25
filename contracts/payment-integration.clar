;; Payment Integration Contract
;; Manages unified fare system

(define-constant ERR_INSUFFICIENT_BALANCE (err u300))
(define-constant ERR_PAYMENT_NOT_FOUND (err u301))
(define-constant ERR_UNAUTHORIZED (err u302))
(define-constant ERR_INVALID_AMOUNT (err u303))

;; Payment status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_COMPLETED u1)
(define-constant STATUS_FAILED u2)
(define-constant STATUS_REFUNDED u3)

;; Data structures
(define-map user-balances
  { user-id: principal }
  { balance: uint }
)

(define-map payments
  { payment-id: uint }
  {
    user-id: principal,
    provider-id: principal,
    journey-id: uint,
    amount: uint,
    status: uint,
    timestamp: uint
  }
)

(define-map provider-earnings
  { provider-id: principal }
  { total-earnings: uint }
)

(define-data-var next-payment-id uint u1)

;; Public functions
(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (match (map-get? user-balances { user-id: tx-sender })
      existing-balance
      (map-set user-balances
        { user-id: tx-sender }
        { balance: (+ (get balance existing-balance) amount) }
      )
      (map-set user-balances
        { user-id: tx-sender }
        { balance: amount }
      )
    )
    (ok true)
  )
)

(define-public (process-payment (provider-id principal) (journey-id uint) (amount uint))
  (let (
    (payment-id (var-get next-payment-id))
    (user-balance (default-to { balance: u0 } (map-get? user-balances { user-id: tx-sender })))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get balance user-balance) amount) ERR_INSUFFICIENT_BALANCE)

    ;; Deduct from user balance
    (map-set user-balances
      { user-id: tx-sender }
      { balance: (- (get balance user-balance) amount) }
    )

    ;; Add to provider earnings
    (match (map-get? provider-earnings { provider-id: provider-id })
      existing-earnings
      (map-set provider-earnings
        { provider-id: provider-id }
        { total-earnings: (+ (get total-earnings existing-earnings) amount) }
      )
      (map-set provider-earnings
        { provider-id: provider-id }
        { total-earnings: amount }
      )
    )

    ;; Record payment
    (map-set payments
      { payment-id: payment-id }
      {
        user-id: tx-sender,
        provider-id: provider-id,
        journey-id: journey-id,
        amount: amount,
        status: STATUS_COMPLETED,
        timestamp: block-height
      }
    )

    (var-set next-payment-id (+ payment-id u1))
    (ok payment-id)
  )
)

(define-public (refund-payment (payment-id uint))
  (match (map-get? payments { payment-id: payment-id })
    payment-data
    (begin
      (asserts! (is-eq (get status payment-data) STATUS_COMPLETED) ERR_INVALID_AMOUNT)

      ;; Update payment status
      (map-set payments
        { payment-id: payment-id }
        (merge payment-data { status: STATUS_REFUNDED })
      )

      ;; Refund to user
      (let ((user-balance (default-to { balance: u0 } (map-get? user-balances { user-id: (get user-id payment-data) }))))
        (map-set user-balances
          { user-id: (get user-id payment-data) }
          { balance: (+ (get balance user-balance) (get amount payment-data)) }
        )
      )

      ;; Deduct from provider
      (match (map-get? provider-earnings { provider-id: (get provider-id payment-data) })
        provider-data
        (map-set provider-earnings
          { provider-id: (get provider-id payment-data) }
          { total-earnings: (- (get total-earnings provider-data) (get amount payment-data)) }
        )
        false ;; Provider not found, but continue
      )

      (ok true)
    )
    ERR_PAYMENT_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-user-balance (user-id principal))
  (default-to { balance: u0 } (map-get? user-balances { user-id: user-id }))
)

(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-provider-earnings (provider-id principal))
  (default-to { total-earnings: u0 } (map-get? provider-earnings { provider-id: provider-id }))
)
