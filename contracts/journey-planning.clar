;; Journey Planning Contract
;; Coordinates multimodal trips

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_JOURNEY_NOT_FOUND (err u201))
(define-constant ERR_INVALID_JOURNEY (err u202))
(define-constant ERR_JOURNEY_COMPLETED (err u203))

;; Journey status constants
(define-constant STATUS_PLANNED u0)
(define-constant STATUS_IN_PROGRESS u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_CANCELLED u3)

;; Data structures
(define-map journeys
  { journey-id: uint }
  {
    user-id: principal,
    origin: (string-ascii 100),
    destination: (string-ascii 100),
    departure-time: uint,
    arrival-time: uint,
    status: uint,
    total-cost: uint,
    created-at: uint
  }
)

(define-map journey-segments
  { journey-id: uint, segment-id: uint }
  {
    provider-id: principal,
    transport-mode: (string-ascii 50),
    start-location: (string-ascii 100),
    end-location: (string-ascii 100),
    start-time: uint,
    end-time: uint,
    cost: uint,
    status: uint
  }
)

(define-data-var next-journey-id uint u1)

;; Public functions
(define-public (create-journey
  (origin (string-ascii 100))
  (destination (string-ascii 100))
  (departure-time uint)
  (estimated-arrival uint)
)
  (let ((journey-id (var-get next-journey-id)))
    (map-set journeys
      { journey-id: journey-id }
      {
        user-id: tx-sender,
        origin: origin,
        destination: destination,
        departure-time: departure-time,
        arrival-time: estimated-arrival,
        status: STATUS_PLANNED,
        total-cost: u0,
        created-at: block-height
      }
    )
    (var-set next-journey-id (+ journey-id u1))
    (ok journey-id)
  )
)

(define-public (add-journey-segment
  (journey-id uint)
  (segment-id uint)
  (provider-id principal)
  (transport-mode (string-ascii 50))
  (start-location (string-ascii 100))
  (end-location (string-ascii 100))
  (start-time uint)
  (end-time uint)
  (cost uint)
)
  (match (map-get? journeys { journey-id: journey-id })
    journey-data
    (begin
      (asserts! (is-eq (get user-id journey-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status journey-data) STATUS_PLANNED) ERR_JOURNEY_COMPLETED)
      (map-set journey-segments
        { journey-id: journey-id, segment-id: segment-id }
        {
          provider-id: provider-id,
          transport-mode: transport-mode,
          start-location: start-location,
          end-location: end-location,
          start-time: start-time,
          end-time: end-time,
          cost: cost,
          status: STATUS_PLANNED
        }
      )
      ;; Update total cost
      (map-set journeys
        { journey-id: journey-id }
        (merge journey-data { total-cost: (+ (get total-cost journey-data) cost) })
      )
      (ok true)
    )
    ERR_JOURNEY_NOT_FOUND
  )
)

(define-public (start-journey (journey-id uint))
  (match (map-get? journeys { journey-id: journey-id })
    journey-data
    (begin
      (asserts! (is-eq (get user-id journey-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status journey-data) STATUS_PLANNED) ERR_INVALID_JOURNEY)
      (map-set journeys
        { journey-id: journey-id }
        (merge journey-data { status: STATUS_IN_PROGRESS })
      )
      (ok true)
    )
    ERR_JOURNEY_NOT_FOUND
  )
)

(define-public (complete-journey (journey-id uint))
  (match (map-get? journeys { journey-id: journey-id })
    journey-data
    (begin
      (asserts! (is-eq (get user-id journey-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status journey-data) STATUS_IN_PROGRESS) ERR_INVALID_JOURNEY)
      (map-set journeys
        { journey-id: journey-id }
        (merge journey-data { status: STATUS_COMPLETED, arrival-time: block-height })
      )
      (ok true)
    )
    ERR_JOURNEY_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-journey (journey-id uint))
  (map-get? journeys { journey-id: journey-id })
)

(define-read-only (get-journey-segment (journey-id uint) (segment-id uint))
  (map-get? journey-segments { journey-id: journey-id, segment-id: segment-id })
)

(define-read-only (get-user-journeys (user-id principal))
  ;; In a real implementation, this would return a list of journey IDs for the user
  ;; For simplicity, we'll return the next journey ID as an indicator
  (var-get next-journey-id)
)
