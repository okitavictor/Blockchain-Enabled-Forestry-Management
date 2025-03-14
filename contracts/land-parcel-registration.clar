;; Land Parcel Registration Contract
;; Records forest areas and their characteristics

(define-data-var admin principal tx-sender)

;; Map of parcel IDs to parcel details
(define-map parcels
  uint
  {
    owner: principal,
    location: (string-ascii 100),
    area-hectares: uint,
    forest-type: (string-ascii 50),
    age-years: uint,
    species-diversity: uint,
    protected-status: bool,
    registration-date: uint
  }
)

;; Counter for parcel IDs
(define-data-var next-parcel-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Register a new land parcel
(define-public (register-parcel
  (location (string-ascii 100))
  (area-hectares uint)
  (forest-type (string-ascii 50))
  (age-years uint)
  (species-diversity uint)
  (protected-status bool)
)
  (let (
    (parcel-id (var-get next-parcel-id))
  )
    ;; Only landowners can register parcels
    (map-set parcels
      parcel-id
      {
        owner: tx-sender,
        location: location,
        area-hectares: area-hectares,
        forest-type: forest-type,
        age-years: age-years,
        species-diversity: species-diversity,
        protected-status: protected-status,
        registration-date: block-height
      }
    )

    ;; Increment the parcel ID counter
    (var-set next-parcel-id (+ parcel-id u1))

    (ok parcel-id)
  )
)

;; Update parcel details
(define-public (update-parcel
  (parcel-id uint)
  (forest-type (string-ascii 50))
  (age-years uint)
  (species-diversity uint)
  (protected-status bool)
)
  (let (
    (parcel (unwrap! (map-get? parcels parcel-id) (err u2)))
  )
    ;; Only the parcel owner can update
    (asserts! (is-eq tx-sender (get owner parcel)) (err u3))

    ;; Update the parcel
    (map-set parcels
      parcel-id
      (merge parcel {
        forest-type: forest-type,
        age-years: age-years,
        species-diversity: species-diversity,
        protected-status: protected-status
      })
    )

    (ok true)
  )
)

;; Transfer parcel ownership
(define-public (transfer-parcel (parcel-id uint) (new-owner principal))
  (let (
    (parcel (unwrap! (map-get? parcels parcel-id) (err u2)))
  )
    ;; Only the parcel owner can transfer
    (asserts! (is-eq tx-sender (get owner parcel)) (err u3))

    ;; Update the parcel
    (map-set parcels
      parcel-id
      (merge parcel { owner: new-owner })
    )

    (ok true)
  )
)

;; Get parcel details
(define-read-only (get-parcel (parcel-id uint))
  (map-get? parcels parcel-id)
)

;; Check if a parcel is protected
(define-read-only (is-protected (parcel-id uint))
  (match (map-get? parcels parcel-id)
    parcel (get protected-status parcel)
    false)
)

;; Get parcel area
(define-read-only (get-parcel-area (parcel-id uint))
  (match (map-get? parcels parcel-id)
    parcel (get area-hectares parcel)
    u0)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u4))
    (var-set admin new-admin)
    (ok true)
  )
)

