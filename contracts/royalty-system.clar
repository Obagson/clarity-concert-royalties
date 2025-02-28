;; Concert Royalty System Contract with Tiered Royalties and Ticket Sales

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-SOLD-OUT (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))
(define-constant ERR-INVALID-DATE (err u105))
(define-constant ERR-PURCHASE-LIMIT (err u106))
(define-constant MAX-TICKETS-PER-PURCHASE u10)

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
    is-settled: bool,
    status: (string-ascii 20)
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

;; Events
(define-data-var last-event-id uint u0)

(define-public (register-artist (artist-name (string-ascii 50)) (royalty uint) (tier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (< royalty u100) ERR-INVALID-AMOUNT)
        (asserts! (<= tier u3) ERR-INVALID-AMOUNT)
        (print {event: "artist-registered", artist: tx-sender, name: artist-name})
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
        (asserts! (> concert-date (unwrap! (get-block-info? time u0) ERR-INVALID-DATE)) ERR-INVALID-DATE)
        (print {event: "concert-created", id: concert-id, name: concert-name})
        (ok (map-set concerts concert-id {
            name: concert-name,
            date: concert-date,
            total-revenue: u0,
            ticket-price: price,
            total-tickets: total-tickets,
            tickets-sold: u0,
            is-settled: false,
            status: "upcoming"
        }))
    )
)

(define-public (purchase-tickets (concert-id uint) (quantity uint))
    (let (
        (concert (unwrap! (map-get? concerts concert-id) ERR-NOT-FOUND))
        (total-cost (* quantity (get ticket-price concert)))
    )
    (begin
        (asserts! (<= quantity MAX-TICKETS-PER-PURCHASE) ERR-PURCHASE-LIMIT)
        (asserts! (<= (+ quantity (get tickets-sold concert)) (get total-tickets concert)) ERR-SOLD-OUT)
        (try! (stx-transfer? total-cost tx-sender contract-owner))
        (print {event: "tickets-purchased", concert-id: concert-id, buyer: tx-sender, quantity: quantity})
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
        (total-revenue (get total-revenue concert))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-settled concert)) ERR-NOT-AUTHORIZED)
        (print {event: "royalties-distributed", concert-id: concert-id, revenue: total-revenue})
        (ok (map-set concerts concert-id 
            (merge concert {
                is-settled: true,
                status: "completed"
            })
        ))
    ))
)

;; Additional getter for artist earnings
(define-read-only (get-artist-earnings (artist principal))
    (match (map-get? artists artist)
        artist-data (ok (get total-earned artist-data))
        ERR-NOT-FOUND
    )
)

;; Existing read-only functions remain unchanged
[Previous read-only functions...]
