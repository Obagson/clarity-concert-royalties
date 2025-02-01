;; Concert Royalty System Contract with Tiered Royalties and Ticket Sales

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-SOLD-OUT (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))

;; Data Variables
(define-map artists principal {
    name: (string-ascii 50),
    royalty-percentage: uint,
    tier: uint,
    total-earned: uint
})

(define-map concerts uint {
    name: (string-ascii 100),
    date: uint,
    total-revenue: uint,
    ticket-price: uint,
    total-tickets: uint,
    tickets-sold: uint,
    is-settled: bool
})

(define-map concert-artists {concert-id: uint, artist: principal} {
    performance-order: uint,
    payment-status: bool,
    bonus-percentage: uint
})

(define-map ticket-holders {concert-id: uint, holder: principal} {
    quantity: uint,
    claimed: bool
})

;; Public Functions
(define-public (register-artist (artist-name (string-ascii 50)) (royalty uint) (tier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (< royalty u100) ERR-INVALID-AMOUNT)
        (asserts! (<= tier u3) ERR-INVALID-AMOUNT)
        (ok (map-set artists tx-sender {
            name: artist-name,
            royalty-percentage: royalty,
            tier: tier,
            total-earned: u0
        }))
    )
)

(define-public (create-concert (concert-id uint) (concert-name (string-ascii 100)) (concert-date uint) (price uint) (total-tickets uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (ok (map-set concerts concert-id {
            name: concert-name,
            date: concert-date,
            total-revenue: u0,
            ticket-price: price,
            total-tickets: total-tickets,
            tickets-sold: u0,
            is-settled: false
        }))
    )
)

(define-public (add-artist-to-concert (concert-id uint) (artist principal) (performance-order uint) (bonus-percentage uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= bonus-percentage u20) ERR-INVALID-AMOUNT)
        (ok (map-set concert-artists {concert-id: concert-id, artist: artist} {
            performance-order: performance-order,
            payment-status: false,
            bonus-percentage: bonus-percentage
        }))
    )
)

(define-public (purchase-tickets (concert-id uint) (quantity uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
        (total-cost (* quantity (get ticket-price concert)))
    )
    (begin
        (asserts! (<= (+ quantity (get tickets-sold concert)) (get total-tickets concert)) ERR-SOLD-OUT)
        (try! (stx-transfer? total-cost tx-sender contract-owner))
        (map-set concerts concert-id 
            (merge concert {
                tickets-sold: (+ quantity (get tickets-sold concert)),
                total-revenue: (+ total-cost (get total-revenue concert))
            })
        )
        (map-set ticket-holders {concert-id: concert-id, holder: tx-sender} {
            quantity: quantity,
            claimed: false
        })
        (ok true)
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

(define-public (claim-ticket (concert-id uint))
    (let (
        (tickets (unwrap! (map-get? ticket-holders {concert-id: concert-id, holder: tx-sender}) ERR-NOT-FOUND))
    )
    (begin
        (asserts! (not (get claimed tickets)) ERR-ALREADY-CLAIMED)
        (ok (map-set ticket-holders {concert-id: concert-id, holder: tx-sender}
            (merge tickets {claimed: true})
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

(define-read-only (get-ticket-info (concert-id uint) (holder principal))
    (map-get? ticket-holders {concert-id: concert-id, holder: holder})
)
