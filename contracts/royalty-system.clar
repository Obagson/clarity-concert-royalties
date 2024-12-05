;; Concert Royalty System Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NOT-FOUND (err u102))

;; Data Variables
(define-map artists principal {
    name: (string-ascii 50),
    royalty-percentage: uint,
    total-earned: uint
})

(define-map concerts uint {
    name: (string-ascii 100),
    date: uint,
    total-revenue: uint,
    is-settled: bool
})

(define-map concert-artists {concert-id: uint, artist: principal} {
    performance-order: uint,
    payment-status: bool
})

;; Public Functions
(define-public (register-artist (artist-name (string-ascii 50)) (royalty uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (< royalty u100) ERR-INVALID-AMOUNT)
        (ok (map-set artists tx-sender {
            name: artist-name,
            royalty-percentage: royalty,
            total-earned: u0
        }))
    )
)

(define-public (create-concert (concert-id uint) (concert-name (string-ascii 100)) (concert-date uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set concerts concert-id {
            name: concert-name,
            date: concert-date,
            total-revenue: u0,
            is-settled: false
        }))
    )
)

(define-public (add-artist-to-concert (concert-id uint) (artist principal) (performance-order uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set concert-artists {concert-id: concert-id, artist: artist} {
            performance-order: performance-order,
            payment-status: false
        }))
    )
)

(define-public (record-revenue (concert-id uint) (amount uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set concerts concert-id 
            (merge concert {total-revenue: (+ amount (get total-revenue concert))})
        ))
    ))
)

(define-public (distribute-royalties (concert-id uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-settled concert)) ERR-NOT-AUTHORIZED)
        (ok (map-set concerts concert-id 
            (merge concert {is-settled: true})
        ))
    ))
)

;; Read Only Functions
(define-read-only (get-artist-info (artist principal))
    (map-get? artists artist)
)

(define-read-only (get-concert-info (concert-id uint))
    (map-get? concerts concert-id)
)

(define-read-only (get-artist-concert-status (concert-id uint) (artist principal))
    (map-get? concert-artists {concert-id: concert-id, artist: artist})
)
