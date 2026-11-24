import { useNavigate } from 'react-router-dom'

export default function AboutPage() {
  const navigate = useNavigate()

  return (
    <div className="about-page">

      {/* ── MISSION ── */}
      <section className="about-mission">
        <div className="about-mission-inner">
          <div className="about-eyebrow">The Mission</div>
          <h1 className="about-mission-title">
            Built to give buyers a better experience<br />
            <span className="red">before auction day.</span>
          </h1>
          <p className="about-mission-body">
            If you've ever shown up to a tow auction without knowing what's available,
            you know the problem. You're walking a lot, squinting at windshield stickers,
            and hoping something worth bidding on shows up. AuctionLab was built to fix that.
          </p>
          <p className="about-mission-body">
            Every vehicle in this inventory comes from real impound data under Georgia's
            Title 40‑11‑2 law. The data flows from the towing company's records into a
            SQL Server database, through a REST API, and into this interface — so you can
            filter by make, year, and body type before you ever leave the house.
          </p>
          <p className="about-mission-body">
            No scraping. No mock data. Live inventory, updated from the source.
          </p>
        </div>

        {/* Pipeline graphic */}
        <div className="about-pipeline">
          <div className="pipeline-step">
            <div className="pipeline-icon">🚗</div>
            <div className="pipeline-label">Tow Records</div>
          </div>
          <div className="pipeline-arrow">→</div>
          <div className="pipeline-step">
            <div className="pipeline-icon">🗄️</div>
            <div className="pipeline-label">SQL Server</div>
          </div>
          <div className="pipeline-arrow">→</div>
          <div className="pipeline-step">
            <div className="pipeline-icon">⚡</div>
            <div className="pipeline-label">Node API</div>
          </div>
          <div className="pipeline-arrow">→</div>
          <div className="pipeline-step">
            <div className="pipeline-icon">💻</div>
            <div className="pipeline-label">React UI</div>
          </div>
        </div>
      </section>

      {/* ── DIVIDER ── */}
      <div className="about-divider" />

      {/* ── BUILDER BIO ── */}
      <section className="about-builder">
        <div className="about-builder-left">
          <div className="about-eyebrow">The Builder</div>
          <h2 className="about-builder-name">Marvin Ndungu</h2>
          <div className="about-builder-role">Sr. Database Developer · Atlanta, GA</div>

          <p className="about-builder-body">
            I've spent 15+ years deep in SQL Server — stored procedures, query optimization,
            schema design, and the kind of data work that keeps production systems running.
            Most of that career has been invisible to the front end. AuctionLab was a chance
            to change that.
          </p>
          <p className="about-builder-body">
            This project is full-stack, end to end: I designed the database schema, wrote the
            T-SQL stored procedures, built the Node.js REST API, and built the React frontend
            from scratch — no component libraries, custom CSS, real data. It's proof that the
            database skills translate all the way to the browser.
          </p>
          <p className="about-builder-body">
            I'm currently transitioning toward data engineering and full-stack roles. If you're
            looking for someone who can own the data layer and build the product around it,
            let's talk.
          </p>

          <div className="about-builder-links">
            <a
              className="about-link-btn"
              href="https://github.com/mndungugit"
              target="_blank"
              rel="noreferrer"
            >
              GitHub ↗
            </a>
            <button className="btn-primary" onClick={() => navigate('/')}>
              Browse the App →
            </button>
          </div>
        </div>

        <div className="about-builder-right">
          <div className="about-skills-card">
            <div className="about-skills-label">Core Stack</div>
            <div className="about-skills-list">
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>SQL Server · T-SQL · Stored Procedures</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>Node.js · Express · REST APIs</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>React 18 · Vite · React Router</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>PowerShell · Git · SSIS</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>Custom CSS · Responsive Design</span>
              </div>
            </div>

            <div className="about-skills-label" style={{ marginTop: '1.5rem' }}>Experience</div>
            <div className="about-skills-list">
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>Strategic Link Consulting — Sr. DB Developer</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>Honeywell · Georgia-Pacific · SAP America</span>
              </div>
              <div className="about-skill-row">
                <span className="skill-dot" />
                <span>B.S. Information Systems — Kennesaw State</span>
              </div>
            </div>
          </div>
        </div>
      </section>

    </div>
  )
}
