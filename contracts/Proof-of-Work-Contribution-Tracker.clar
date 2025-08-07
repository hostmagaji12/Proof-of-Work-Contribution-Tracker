(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_HASH (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_REWARD (err u105))

(define-constant STREAK_BONUS_MULTIPLIER u50)
(define-constant MAX_STREAK_BONUS u500000)
(define-constant STREAK_WINDOW u144)

(define-data-var total-contributors uint u0)
(define-data-var total-contributions uint u0)
(define-data-var reward-per-contribution uint u1000000)

(define-map contributors 
  principal 
  {
    contributions: uint,
    total-rewards: uint,
    first-contribution-block: uint,
    last-contribution-block: uint,
    verified: bool
  }
)

(define-map contributions 
  uint 
  {
    contributor: principal,
    commit-hash: (buff 32),
    repository: (string-ascii 100),
    timestamp: uint,
    block-height: uint,
    verified: bool,
    reward-claimed: bool
  }
)

(define-map commit-hashes (buff 32) uint)

(define-public (register-contributor)
  (let ((contributor tx-sender))
    (asserts! (is-none (map-get? contributors contributor)) ERR_ALREADY_EXISTS)
    (map-set contributors contributor {
      contributions: u0,
      total-rewards: u0,
      first-contribution-block: stacks-block-height,
      last-contribution-block: stacks-block-height,
      verified: false
    })
    (var-set total-contributors (+ (var-get total-contributors) u1))
    (ok true)
  )
)

(define-public (submit-contribution (commit-hash (buff 32)) (repository (string-ascii 100)))
  (let (
    (contributor tx-sender)
    (contribution-id (var-get total-contributions))
    (current-block stacks-block-height)
  )
    (asserts! (is-some (map-get? contributors contributor)) ERR_NOT_FOUND)
    (asserts! (is-none (map-get? commit-hashes commit-hash)) ERR_ALREADY_EXISTS)
    (asserts! (> (len commit-hash) u0) ERR_INVALID_HASH)
    
    (map-set contributions contribution-id {
      contributor: contributor,
      commit-hash: commit-hash,
      repository: repository,
      timestamp: (default-to u0 (get-stacks-block-info? time current-block)),
      block-height: current-block,
      verified: false,
      reward-claimed: false
    })
    
    (map-set commit-hashes commit-hash contribution-id)
    (var-set total-contributions (+ contribution-id u1))
    
    (match (map-get? contributors contributor)
      contributor-data (map-set contributors contributor (merge contributor-data {
        contributions: (+ (get contributions contributor-data) u1),
        last-contribution-block: current-block
      }))
      false
    )
    
    (ok contribution-id)
  )
)

(define-public (verify-contribution (contribution-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? contributions contribution-id)
      contribution-data (begin
        (map-set contributions contribution-id (merge contribution-data {
          verified: true
        }))
        (match (map-get? contributors (get contributor contribution-data))
          contributor-data (map-set contributors (get contributor contribution-data) (merge contributor-data {
            verified: true
          }))
          false
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (claim-reward (contribution-id uint))
  (let (
    (contributor tx-sender)
    (reward-amount (var-get reward-per-contribution))
  )
    (match (map-get? contributions contribution-id)
      contribution-data (begin
        (asserts! (is-eq contributor (get contributor contribution-data)) ERR_UNAUTHORIZED)
        (asserts! (get verified contribution-data) ERR_UNAUTHORIZED)
        (asserts! (not (get reward-claimed contribution-data)) ERR_ALREADY_EXISTS)
        (asserts! (>= (stx-get-balance (as-contract tx-sender)) reward-amount) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? reward-amount tx-sender contributor)))
        
        (map-set contributions contribution-id (merge contribution-data {
          reward-claimed: true
        }))
        
        (match (map-get? contributors contributor)
          contributor-data (map-set contributors contributor (merge contributor-data {
            total-rewards: (+ (get total-rewards contributor-data) reward-amount)
          }))
          false
        )
        
        (ok reward-amount)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (update-reward-amount (new-reward uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-reward u0) ERR_INVALID_REWARD)
    (var-set reward-per-contribution new-reward)
    (ok true)
  )
)

(define-public (fund-contract)
  (let ((amount (stx-get-balance tx-sender)))
    (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

(define-read-only (get-contributor (contributor principal))
  (map-get? contributors contributor)
)

(define-read-only (get-contribution (contribution-id uint))
  (map-get? contributions contribution-id)
)

(define-read-only (get-contribution-by-hash (commit-hash (buff 32)))
  (match (map-get? commit-hashes commit-hash)
    contribution-id (map-get? contributions contribution-id)
    none
  )
)

(define-read-only (get-contract-stats)
  {
    total-contributors: (var-get total-contributors),
    total-contributions: (var-get total-contributions),
    reward-per-contribution: (var-get reward-per-contribution),
    contract-balance: (stx-get-balance (as-contract tx-sender))
  }
)

(define-read-only (get-contributor-stats (contributor principal))
  (match (map-get? contributors contributor)
    contributor-data (some {
      contributions: (get contributions contributor-data),
      total-rewards: (get total-rewards contributor-data),
      verified: (get verified contributor-data),
      active-days: (if (> (get last-contribution-block contributor-data) (get first-contribution-block contributor-data))
                     (- (get last-contribution-block contributor-data) (get first-contribution-block contributor-data))
                     u0)
    })
    none
  )
)

(define-read-only (is-hash-used (commit-hash (buff 32)))
  (is-some (map-get? commit-hashes commit-hash))
)

(define-read-only (get-reward-amount)
  (var-get reward-per-contribution)
)

(define-map contributor-streaks
  principal
  {
    current-streak: uint,
    longest-streak: uint,
    last-contribution-day: uint,
    total-streak-bonus: uint
  }
)

(define-private (get-day-from-block (blk-height uint))
  (/ blk-height STREAK_WINDOW)
)

(define-private (calculate-streak-bonus (streak uint))
  (let ((bonus (* streak STREAK_BONUS_MULTIPLIER)))
    (if (> bonus MAX_STREAK_BONUS) MAX_STREAK_BONUS bonus)
  )
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

(define-public (update-contribution-streak (contributor principal))
  (let (
    (current-day (get-day-from-block stacks-block-height))
    (existing-streak (default-to 
      { current-streak: u0, longest-streak: u0, last-contribution-day: u0, total-streak-bonus: u0 }
      (map-get? contributor-streaks contributor)))
    (last-day (get last-contribution-day existing-streak))
    (current-streak-count (get current-streak existing-streak))
  )
    (let (
      (new-streak (if (is-eq current-day (+ last-day u1))
                    (+ current-streak-count u1)
                    (if (is-eq current-day last-day) current-streak-count u1)))
      (new-longest (max new-streak (get longest-streak existing-streak)))
      (streak-bonus (calculate-streak-bonus new-streak))
    )
      (map-set contributor-streaks contributor {
        current-streak: new-streak,
        longest-streak: new-longest,
        last-contribution-day: current-day,
        total-streak-bonus: (+ (get total-streak-bonus existing-streak) streak-bonus)
      })
      (ok streak-bonus)
    )
  )
)

(define-read-only (get-contributor-streak (contributor principal))
  (map-get? contributor-streaks contributor)
)

(define-read-only (get-streak-bonus-preview (streak uint))
  (calculate-streak-bonus streak)
)

(define-read-only (get-top-streaks (limit uint))
  (ok "Manual implementation needed for sorting")
)

(define-read-only (is-streak-active (contributor principal))
  (match (map-get? contributor-streaks contributor)
    streak-data (let ((days-since (- (get-day-from-block stacks-block-height) 
                                   (get last-contribution-day streak-data))))
                  (<= days-since u1))
    false
  )
)

(define-public (claim-streak-bonus (contribution-id uint))
  (let ((contributor tx-sender))
    (match (map-get? contributions contribution-id)
      contribution-data (begin
        (asserts! (is-eq contributor (get contributor contribution-data)) ERR_UNAUTHORIZED)
        (asserts! (get verified contribution-data) ERR_UNAUTHORIZED)
        (unwrap! (update-contribution-streak contributor) ERR_UNAUTHORIZED)
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)