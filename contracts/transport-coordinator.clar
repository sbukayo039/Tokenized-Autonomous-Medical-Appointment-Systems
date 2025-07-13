;; Transportation Coordination Contract
;; Manages medical appointment travel arrangements

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_RIDE_NOT_FOUND (err u401))
(define-constant ERR_INVALID_RIDE (err u402))
(define-constant ERR_INSUFFICIENT_BALANCE (err u403))
(define-constant ERR_RIDE_ALREADY_ASSIGNED (err u404))

;; Data Variables
(define-data-var ride-counter uint u0)
(define-data-var base-fare uint u2000) ;; Base fare in micro-STX

;; Data Maps
(define-map ride-requests
  { ride-id: uint }
  {
    patient: principal,
    appointment-id: uint,
    pickup-location: (string-ascii 200),
    destination: (string-ascii 200),
    pickup-time: uint,
    ride-type: (string-ascii 20),
    special-requirements: (string-ascii 300),
    estimated-fare: uint,
    status: (string-ascii 20),
    created-at: uint,
    driver: (optional principal),
    assigned-at: (optional uint)
  }
)

(define-map driver-profiles
  { driver: principal }
  {
    name: (string-ascii 100),
    vehicle-type: (string-ascii 50),
    license-plate: (string-ascii 20),
    rating: uint,
    medical-certified: bool,
    available: bool,
    location: (string-ascii 200)
  }
)

(define-map ride-assignments
  { driver: principal, ride-id: uint }
  {
    accepted: bool,
    pickup-confirmed: bool,
    dropoff-confirmed: bool,
    completed-at: (optional uint)
  }
)

(define-map patient-ride-history
  { patient: principal, ride-id: uint }
  { rating: (optional uint), feedback: (optional (string-ascii 500)) }
)

;; Token balances for transportation payments
(define-map transport-balances
  { owner: principal }
  { balance: uint }
)

;; Public Functions

;; Register as a driver
(define-public (register-driver
  (name (string-ascii 100))
  (vehicle-type (string-ascii 50))
  (license-plate (string-ascii 20))
  (medical-certified bool)
  (location (string-ascii 200)))
  (begin
    (map-set driver-profiles
      { driver: tx-sender }
      {
        name: name,
        vehicle-type: vehicle-type,
        license-plate: license-plate,
        rating: u5, ;; Start with 5-star rating
        medical-certified: medical-certified,
        available: true,
        location: location
      }
    )
    (ok true)
  )
)

;; Update driver availability
(define-public (update-availability (available bool) (location (string-ascii 200)))
  (match (map-get? driver-profiles { driver: tx-sender })
    driver-info
      (begin
        (map-set driver-profiles
          { driver: tx-sender }
          (merge driver-info { available: available, location: location })
        )
        (ok true)
      )
    ERR_UNAUTHORIZED
  )
)

;; Request ride for medical appointment
(define-public (request-ride
  (appointment-id uint)
  (pickup-location (string-ascii 200))
  (destination (string-ascii 200))
  (pickup-time uint)
  (ride-type (string-ascii 20))
  (special-requirements (string-ascii 300)))
  (let
    (
      (ride-id (+ (var-get ride-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (estimated-fare (calculate-fare ride-type))
      (patient-balance (default-to u0 (get balance (map-get? transport-balances { owner: tx-sender }))))
    )
    (if (< patient-balance estimated-fare)
      ERR_INSUFFICIENT_BALANCE
      (begin

        ;; Reserve fare amount
        (map-set transport-balances
          { owner: tx-sender }
          { balance: (- patient-balance estimated-fare) }
        )

        (map-set ride-requests
          { ride-id: ride-id }
          {
            patient: tx-sender,
            appointment-id: appointment-id,
            pickup-location: pickup-location,
            destination: destination,
            pickup-time: pickup-time,
            ride-type: ride-type,
            special-requirements: special-requirements,
            estimated-fare: estimated-fare,
            status: "requested",
            created-at: current-time,
            driver: none,
            assigned-at: none
          }
        )

        ;; Update counter
        (var-set ride-counter ride-id)

        (ok ride-id)
      )
    )
  )
)

;; Accept ride request (driver function)
(define-public (accept-ride (ride-id uint))
  (match (map-get? ride-requests { ride-id: ride-id })
    ride-info
      (begin
        (if (is-none (map-get? driver-profiles { driver: tx-sender }))
          ERR_UNAUTHORIZED
          (if (not (is-eq (get status ride-info) "requested"))
            ERR_RIDE_ALREADY_ASSIGNED
            (begin

              (let
                (
                  (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
                )
                ;; Update ride with driver assignment
                (map-set ride-requests
                  { ride-id: ride-id }
                  (merge ride-info {
                    status: "assigned",
                    driver: (some tx-sender),
                    assigned-at: (some current-time)
                  })
                )

                ;; Create assignment record
                (map-set ride-assignments
                  { driver: tx-sender, ride-id: ride-id }
                  {
                    accepted: true,
                    pickup-confirmed: false,
                    dropoff-confirmed: false,
                    completed-at: none
                  }
                )

                (ok true)
              )
            )
          )
        )
      )
    ERR_RIDE_NOT_FOUND
  )
)

;; Confirm pickup
(define-public (confirm-pickup (ride-id uint))
  (match (map-get? ride-assignments { driver: tx-sender, ride-id: ride-id })
    assignment-info
      (begin
        (if (not (get accepted assignment-info))
          ERR_UNAUTHORIZED
          (begin

            (map-set ride-assignments
              { driver: tx-sender, ride-id: ride-id }
              (merge assignment-info { pickup-confirmed: true })
            )

            ;; Update ride status
            (match (map-get? ride-requests { ride-id: ride-id })
              ride-info
                (map-set ride-requests
                  { ride-id: ride-id }
                  (merge ride-info { status: "in-progress" })
                )
              false
            )

            (ok true)
          )
        )
      )
    ERR_RIDE_NOT_FOUND
  )
)

;; Complete ride
(define-public (complete-ride (ride-id uint))
  (match (map-get? ride-assignments { driver: tx-sender, ride-id: ride-id })
    assignment-info
      (begin
        (if (not (get pickup-confirmed assignment-info))
          ERR_INVALID_RIDE
          (begin

            (let
              (
                (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
              )
              ;; Update assignment
              (map-set ride-assignments
                { driver: tx-sender, ride-id: ride-id }
                (merge assignment-info {
                  dropoff-confirmed: true,
                  completed-at: (some current-time)
                })
              )

              ;; Update ride status
              (match (map-get? ride-requests { ride-id: ride-id })
                ride-info
                  (begin
                    (map-set ride-requests
                      { ride-id: ride-id }
                      (merge ride-info { status: "completed" })
                    )

                    ;; Pay driver
                    (let
                      (
                        (driver-balance (default-to u0 (get balance (map-get? transport-balances { owner: tx-sender }))))
                        (fare-amount (get estimated-fare ride-info))
                      )
                      (map-set transport-balances
                        { owner: tx-sender }
                        { balance: (+ driver-balance fare-amount) }
                      )
                    )
                  )
                false
              )

              (ok true)
            )
          )
        )
      )
    ERR_RIDE_NOT_FOUND
  )
)

;; Rate ride (patient function)
(define-public (rate-ride (ride-id uint) (rating uint) (feedback (string-ascii 500)))
  (match (map-get? ride-requests { ride-id: ride-id })
    ride-info
      (begin
        (if (not (is-eq (get patient ride-info) tx-sender))
          ERR_UNAUTHORIZED
          (if (not (is-eq (get status ride-info) "completed"))
            ERR_INVALID_RIDE
            (if (or (< rating u1) (> rating u5))
              ERR_INVALID_RIDE
              (begin

                (map-set patient-ride-history
                  { patient: tx-sender, ride-id: ride-id }
                  { rating: (some rating), feedback: (some feedback) }
                )

                (ok true)
              )
            )
          )
        )
      )
    ERR_RIDE_NOT_FOUND
  )
)

;; Cancel ride
(define-public (cancel-ride (ride-id uint))
  (match (map-get? ride-requests { ride-id: ride-id })
    ride-info
      (begin
        (if (not (is-eq (get patient ride-info) tx-sender))
          ERR_UNAUTHORIZED
          (if (is-eq (get status ride-info) "completed")
            ERR_INVALID_RIDE
            (begin

              ;; Refund patient
              (let
                (
                  (patient-balance (default-to u0 (get balance (map-get? transport-balances { owner: tx-sender }))))
                  (refund-amount (get estimated-fare ride-info))
                )
                (map-set transport-balances
                  { owner: tx-sender }
                  { balance: (+ patient-balance refund-amount) }
                )
              )

              ;; Update ride status
              (map-set ride-requests
                { ride-id: ride-id }
                (merge ride-info { status: "cancelled" })
              )

              (ok true)
            )
          )
        )
      )
    ERR_RIDE_NOT_FOUND
  )
)

;; Mint transport tokens (only contract owner)
(define-public (mint-transport-tokens (recipient principal) (amount uint))
  (begin
    (if (not (is-eq tx-sender CONTRACT_OWNER))
      ERR_UNAUTHORIZED
      (begin

        (let
          (
            (current-balance (default-to u0 (get balance (map-get? transport-balances { owner: recipient }))))
          )
          (map-set transport-balances
            { owner: recipient }
            { balance: (+ current-balance amount) }
          )
          (ok true)
        )
      )
    )
  )
)

;; Private Functions

;; Calculate fare based on ride type
(define-private (calculate-fare (ride-type (string-ascii 20)))
  (if (is-eq ride-type "wheelchair")
    (* (var-get base-fare) u2) ;; 2x for wheelchair accessible
    (if (is-eq ride-type "urgent")
      (+ (var-get base-fare) u1000) ;; +1000 for urgent rides
      (var-get base-fare) ;; Standard fare
    )
  )
)

;; Read-only functions

;; Get ride details
(define-read-only (get-ride (ride-id uint))
  (map-get? ride-requests { ride-id: ride-id })
)

;; Get driver profile
(define-read-only (get-driver-profile (driver principal))
  (map-get? driver-profiles { driver: driver })
)

;; Get ride assignment
(define-read-only (get-ride-assignment (driver principal) (ride-id uint))
  (map-get? ride-assignments { driver: driver, ride-id: ride-id })
)

;; Get transport balance
(define-read-only (get-transport-balance (owner principal))
  (default-to u0 (get balance (map-get? transport-balances { owner: owner })))
)

;; Get ride history
(define-read-only (get-ride-history (patient principal) (ride-id uint))
  (map-get? patient-ride-history { patient: patient, ride-id: ride-id })
)

;; Get base fare
(define-read-only (get-base-fare)
  (var-get base-fare)
)

;; Get ride counter
(define-read-only (get-ride-counter)
  (var-get ride-counter)
)
