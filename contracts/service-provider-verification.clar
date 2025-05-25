;; Service Provider Verification Contract
;; Validates and manages transportation operators

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Provider status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REJECTED u3)

;; Data structures
(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    service-type: (string-ascii 50),
    status: uint,
    verification-date: uint,
    license-number: (string-ascii 50)
  }
)

(define-map provider-ratings
  { provider-id: principal }
  {
    total-rating: uint,
    rating-count: uint,
    average-rating: uint
  }
)

(define-data-var next-provider-id uint u1)

;; Public functions
(define-public (register-provider (name (string-ascii 100)) (service-type (string-ascii 50)) (license-number (string-ascii 50)))
  (let ((provider-id tx-sender))
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        service-type: service-type,
        status: STATUS_PENDING,
        verification-date: block-height,
        license-number: license-number
      }
    )
    (ok provider-id)
  )
)

(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set providers
          { provider-id: provider-id }
          (merge provider-data { status: STATUS_VERIFIED, verification-date: block-height })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

(define-public (suspend-provider (provider-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set providers
          { provider-id: provider-id }
          (merge provider-data { status: STATUS_SUSPENDED })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

(define-public (rate-provider (provider-id principal) (rating uint))
  (begin
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_STATUS)
    (match (map-get? provider-ratings { provider-id: provider-id })
      existing-rating
      (let (
        (new-total (+ (get total-rating existing-rating) rating))
        (new-count (+ (get rating-count existing-rating) u1))
        (new-average (/ new-total new-count))
      )
        (map-set provider-ratings
          { provider-id: provider-id }
          {
            total-rating: new-total,
            rating-count: new-count,
            average-rating: new-average
          }
        )
        (ok new-average)
      )
      (begin
        (map-set provider-ratings
          { provider-id: provider-id }
          {
            total-rating: rating,
            rating-count: u1,
            average-rating: rating
          }
        )
        (ok rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

(define-read-only (get-provider-rating (provider-id principal))
  (map-get? provider-ratings { provider-id: provider-id })
)

(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? providers { provider-id: provider-id })
    provider-data (is-eq (get status provider-data) STATUS_VERIFIED)
    false
  )
)
