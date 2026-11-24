import { useNavigate } from 'react-router-dom'

export default function HowItWorksPage() {
  const navigate = useNavigate()

  return (
    <div className="hiw-page">
      {/* Page header */}
      <div className="hiw-page-header">
        <h1 className="hiw-page-title">
          How It <span className="red">Works</span>
        </h1>
        <p className="hiw-page-sub">
          Everything you need to know about Georgia's Title 40‑11‑2 auction process
          and how to use this site to find your next vehicle.
        </p>
      </div>

      <div className="hiw-grid">
        {/* LEFT — The Auction Process */}
        <div className="hiw-panel">
          <div className="hiw-panel-label">The Auction Process</div>
          <div className="hiw-steps">
            <div className="hiw-step">
              <div className="hiw-step-num">01</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Vehicle Gets Towed</div>
                <div className="hiw-step-desc">
                  A vehicle is towed and impounded under Georgia Title 40‑11‑2 —
                  covering abandoned, unregistered, or illegally parked vehicles.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">02</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Legal Hold Period</div>
                <div className="hiw-step-desc">
                  The towing company notifies the registered owner and holds the
                  vehicle for the state-mandated period before it can be auctioned.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">03</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Listed in Inventory</div>
                <div className="hiw-step-desc">
                  Unclaimed vehicles are added to this site with full details —
                  VIN, year, make, model, and body type.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">04</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Public Auction Day</div>
                <div className="hiw-step-desc">
                  Vehicles go to public auction on the 1st Saturday of every month.
                  Highest bidder wins the vehicle as‑is.
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* RIGHT — Using This Site */}
        <div className="hiw-panel">
          <div className="hiw-panel-label">Using This Site</div>
          <div className="hiw-steps">
            <div className="hiw-step">
              <div className="hiw-step-num">01</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Browse the Inventory</div>
                <div className="hiw-step-desc">
                  All available vehicles are listed on the browse page. Filter by make,
                  year range, or body type to narrow down what you're looking for.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">02</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Research Before You Bid</div>
                <div className="hiw-step-desc">
                  Click any vehicle to see full specs and run a VIN check. Know
                  what you're bidding on before auction day — vehicles are sold as‑is.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">03</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Show Up on Auction Day</div>
                <div className="hiw-step-desc">
                  Bring a valid ID and be ready to pay same‑day if you win.
                  Cash or certified funds only. No online bidding.
                </div>
              </div>
            </div>
            <div className="hiw-step">
              <div className="hiw-step-num">04</div>
              <div className="hiw-step-body">
                <div className="hiw-step-title">Drive It Home</div>
                <div className="hiw-step-desc">
                  Winner receives a bill of sale. You'll handle titling through
                  the Georgia DMV. Most vehicles are driveable or towable same day.
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Auction Day details bar */}
      <div className="hiw-auction-card">
        <div className="hiw-auction-item">
          <div className="hiw-auction-label">When</div>
          <div className="hiw-auction-value">1st Saturday of Every Month</div>
        </div>
        <div className="hiw-auction-divider" />
        <div className="hiw-auction-item">
          <div className="hiw-auction-label">Start Time</div>
          <div className="hiw-auction-value">2:00 PM</div>
        </div>
        <div className="hiw-auction-divider" />
        <div className="hiw-auction-item">
          <div className="hiw-auction-label">Location</div>
          <div className="hiw-auction-value">Marietta, GA</div>
        </div>
        <div className="hiw-auction-divider" />
        <div className="hiw-auction-item">
          <div className="hiw-auction-label">Requirements</div>
          <div className="hiw-auction-value">Valid ID · Cash or Certified Funds</div>
        </div>
      </div>

      {/* CTA */}
      <div className="hiw-cta-row">
        <button className="btn-primary" onClick={() => navigate('/')}>
          Browse Vehicles →
        </button>
      </div>
    </div>
  )
}
