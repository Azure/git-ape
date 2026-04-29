import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import MetricCard from '@site/src/components/MetricCard';

import styles from './index.module.css';

/* ==========================================================================
   SECTION 1: ANIMATED GRADIENT HERO
   ========================================================================== */

function HeroSection() {
  return (
    <header className={styles.heroBanner}>
      <div className="container">
        <div className={styles.heroBadge}>
          <i className="fab fa-github" /> Deploy with GitHub Copilot
        </div>
        <Heading as="h1" className={styles.heroTitle}>
          Platform engineering for the{' '}
          <span className={styles.heroGold}>agentic AI era</span>
        </Heading>
        <p className={styles.heroSubtitle}>
          <strong>Agents over modules. Intent over syntax. Evidence over audits.</strong>
          <br /><br />
          Git-Ape is the implementation of platform engineering for the
          agentic AI era — natural-language intent in, compliant cloud
          deployments out, policy enforced end-to-end.
        </p>
        <div className={styles.buttons}>
          <Link className={styles.btnPrimary} to="/docs/intro">
            <i className="fas fa-rocket" /> Get Started
          </Link>
          <Link className={styles.btnSecondary} to="/docs/vision">
            <i className="fas fa-lightbulb" /> Read the Manifesto
          </Link>
        </div>
      </div>
    </header>
  );
}

/* ==========================================================================
   SECTION 1B: VIDEO INTRO
   ========================================================================== */

function VideoSection() {
  return (
    <section style={{ padding: '3rem 0', background: 'var(--ifm-background-color)' }}>
      <div className="container">
        <div style={{ maxWidth: '880px', margin: '0 auto', textAlign: 'center' }}>
          <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
            Watch the manifesto in 10 minutes
          </Heading>
          <p className={styles.sectionSubtitle}>
            From <a href="https://devblogs.microsoft.com/all-things-azure/platform-engineering-for-the-agentic-ai-era/"
                   target="_blank" rel="noopener noreferrer">Platform Engineering for the Agentic AI Era</a>
          </p>
          <div style={{
            position: 'relative', paddingBottom: '56.25%', height: 0, overflow: 'hidden',
            borderRadius: '15px', boxShadow: '0 10px 40px rgba(0,0,0,0.15)', marginTop: '2rem',
          }}>
            <iframe
              style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', border: 0 }}
              src="https://www.youtube.com/embed/Td6rv_RGArQ"
              title="Platform Engineering for the Agentic AI Era"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              allowFullScreen
            />
          </div>
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 2: IMPACT METRICS
   ========================================================================== */

const metrics = [
  { value: 'Days→Min', label: 'Prompt to reviewed PR', icon: 'fas fa-clock' },
  { value: '50→1', label: 'Modules → Agent', icon: 'fas fa-cubes' },
  { value: '3', label: 'Compliance Layers', icon: 'fas fa-shield-alt' },
  { value: '0', label: 'Stored Secrets (OIDC)', icon: 'fas fa-key' },
  { value: 'Any', label: 'Cloud resource', icon: 'fas fa-cloud' },
  { value: '100%', label: 'Audit Coverage', icon: 'fas fa-file-signature' },
];

function MetricsSection() {
  return (
    <section className={styles.metricsSection}>
      <div className="container">
        <div className={styles.metricsGrid}>
          {metrics.map((m, i) => (
            <MetricCard key={i} value={m.value} label={m.label} icon={m.icon} />
          ))}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 3: WHO IS GIT-APE FOR?
   ========================================================================== */

const personas = [
  {
    title: 'CxOs & CTOs',
    icon: 'fas fa-chart-line',
    desc: 'Compliance visibility, cost governance, and risk reduction — zero jargon dashboards.',
    link: '/docs/personas/for-executives',
    color: '#667eea',
  },
  {
    title: 'Engineering Leads',
    icon: 'fas fa-users-cog',
    desc: 'Developer productivity, architecture quality automation, and team enablement patterns.',
    link: '/docs/personas/for-engineering-leads',
    color: '#764ba2',
  },
  {
    title: 'DevOps & SRE',
    icon: 'fas fa-server',
    desc: 'CI/CD pipelines, OIDC setup, drift detection, and zero-downtime deployment flows.',
    link: '/docs/personas/for-devops',
    color: '#f093fb',
  },
  {
    title: 'Platform Engineering',
    icon: 'fas fa-layer-group',
    desc: 'Self-service guardrails, policy enforcement, naming standards, and multi-env management.',
    link: '/docs/personas/for-platform-engineering',
    color: '#ffd700',
  },
  {
    title: 'Engineers',
    icon: 'fas fa-code',
    desc: 'Quick start, @git-ape conversation walkthrough, skill cheatsheet, and troubleshooting.',
    link: '/docs/personas/for-engineers',
    color: '#2ecc71',
  },
];

function PersonasSection() {
  return (
    <section className={styles.personasSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          Who Is Git-Ape For?
        </Heading>
        <p className={styles.sectionSubtitle}>
          Purpose-built for every role in your cloud journey
        </p>
        <div className={styles.personasGrid}>
          {personas.map((p, i) => (
            <Link key={i} to={p.link} style={{ textDecoration: 'none', color: 'inherit' }}>
              <div className={clsx(styles.capCard)} style={{ textAlign: 'left', height: '100%' }}>
                <div
                  className={styles.capIcon}
                  style={{ background: `linear-gradient(135deg, ${p.color}, ${p.color}aa)`, margin: '0 0 1rem' }}
                >
                  <i className={p.icon} />
                </div>
                <div className={styles.capTitle}>{p.title}</div>
                <p className={styles.capDesc}>{p.desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 4: HOW IT WORKS (TIMELINE)
   ========================================================================== */

const timelineSteps = [
  { title: 'Describe Your Intent', desc: 'Tell @git-ape what you need in natural language — "Deploy a Python Function App with Storage and App Insights."', icon: 'fas fa-comment-dots', badge: 'You' },
  { title: 'Requirements Gathered', desc: 'The Requirements Gatherer agent validates your subscription, checks naming conflicts, and confirms resource details.', icon: 'fas fa-clipboard-check', badge: 'Agent' },
  { title: 'Architecture Designed', desc: 'The Principal Architect agent evaluates against all 5 WAF pillars and recommends the optimal topology.', icon: 'fas fa-drafting-compass', badge: 'Agent' },
  { title: 'Template Generated', desc: 'ARM template is generated with security best practices, managed identities, and least-privilege RBAC baked in.', icon: 'fas fa-file-code', badge: 'Agent' },
  { title: 'Security Gate Passed', desc: 'Every Critical and High severity check must pass before deployment. No shortcuts — blocked until resolved.', icon: 'fas fa-shield-alt', badge: 'Gate' },
  { title: 'Deployed & Verified', desc: 'Resources are deployed via OIDC, integration tests run, and deployment state is committed to your repo.', icon: 'fas fa-check-double', badge: 'CI/CD' },
];

function TimelineSection() {
  return (
    <section className={styles.timelineSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          How It Works
        </Heading>
        <p className={styles.sectionSubtitle}>
          From conversation to production in six stages
        </p>
        <div className={styles.timelineWrapper}>
          {timelineSteps.map((step, i) => (
            <div key={i} style={{ display: 'flex', gap: '1.5rem', marginBottom: '1.5rem', position: 'relative' }}>
              {/* Vertical line */}
              {i < timelineSteps.length - 1 && (
                <div style={{
                  position: 'absolute', left: '27px', top: '56px', bottom: '-1.5rem',
                  width: '3px', background: 'linear-gradient(to bottom, #667eea, #764ba2)',
                  borderRadius: '2px',
                }} />
              )}
              {/* Node */}
              <div style={{
                width: '56px', height: '56px', borderRadius: '50%',
                background: 'linear-gradient(135deg, #667eea, #764ba2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0, color: '#fff', fontSize: '1.1rem',
                boxShadow: '0 4px 15px rgba(102,126,234,0.3)', zIndex: 1,
              }}>
                <i className={step.icon} />
              </div>
              {/* Card */}
              <div className={styles.capCard} style={{ flex: 1, textAlign: 'left' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.4rem' }}>
                  <span className={styles.capTitle} style={{ margin: 0 }}>{step.title}</span>
                  <span style={{
                    fontSize: '0.65rem', fontWeight: 700, padding: '0.1rem 0.5rem',
                    borderRadius: '20px', background: 'linear-gradient(135deg, #667eea, #764ba2)',
                    color: '#fff', letterSpacing: '0.05em', textTransform: 'uppercase',
                  }}>
                    {step.badge}
                  </span>
                </div>
                <p className={styles.capDesc}>{step.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 5: KEY CAPABILITIES
   ========================================================================== */

const capabilities = [
  { title: 'Security Analysis', desc: 'Blocking security gate with auto-fix suggestions for every deployment.', icon: 'fas fa-shield-alt', color: '#e74c3c' },
  { title: 'Cost Estimation', desc: 'Real-time cloud pricing API lookups per resource.', icon: 'fas fa-dollar-sign', color: '#2ecc71' },
  { title: 'WAF Assessment', desc: '5-pillar Well-Architected Framework scoring and recommendations.', icon: 'fas fa-balance-scale', color: '#3498db' },
  { title: 'Policy Compliance', desc: 'Cloud policy assessment against CIS, NIST, and custom frameworks.', icon: 'fas fa-clipboard-list', color: '#9b59b6' },
  { title: 'Drift Detection', desc: 'Detect and reconcile manual changes vs. desired state.', icon: 'fas fa-exchange-alt', color: '#f39c12' },
  { title: 'Two Modes', desc: 'Interactive in VS Code or headless via Copilot Coding Agent.', icon: 'fas fa-sync-alt', color: '#1abc9c' },
  { title: '8 AI Agents', desc: 'Specialized agents from requirements to deployment validation.', icon: 'fas fa-robot', color: '#667eea' },
  { title: '13 Skills', desc: 'Azure and utility skills invoked automatically by agents.', icon: 'fas fa-puzzle-piece', color: '#764ba2' },
];

function CapabilitiesSection() {
  return (
    <section className={styles.capabilitiesSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          Key Capabilities
        </Heading>
        <p className={styles.sectionSubtitle}>
          Enterprise-grade features built into every deployment
        </p>
        <div className={styles.capGrid}>
          {capabilities.map((cap, i) => (
            <div key={i} className={styles.capCard}>
              <div
                className={styles.capIcon}
                style={{ background: `linear-gradient(135deg, ${cap.color}, ${cap.color}cc)` }}
              >
                <i className={cap.icon} />
              </div>
              <div className={styles.capTitle}>{cap.title}</div>
              <p className={styles.capDesc}>{cap.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 6: USE CASES
   ========================================================================== */

const useCases = [
  { title: 'Generate', desc: 'Natural-language intent → IaC template. Any cloud resource type — if there\'s an API, git-ape can call it.', icon: 'fas fa-magic', gradient: 'linear-gradient(135deg, #667eea, #764ba2)', link: '/docs/use-cases/deploy-anything' },
  { title: 'Validate & Plan', desc: 'Security gate, what-if analysis, and cost estimate run before any merge — non-compliant code never reaches your subscription.', icon: 'fas fa-shield-alt', gradient: 'linear-gradient(135deg, #2ecc71, #27ae60)', link: '/docs/use-cases/security-analysis' },
  { title: 'Deploy', desc: 'OIDC-based GitHub Actions deploy on PR merge or /deploy comment. No stored secrets, full audit trail.', icon: 'fas fa-rocket', gradient: 'linear-gradient(135deg, #3498db, #2980b9)', link: '/docs/use-cases/cicd-pipeline' },
  { title: 'Test', desc: 'Post-deployment integration checks verify endpoints, identity, and connectivity — not just “deployment succeeded”.', icon: 'fas fa-vial', gradient: 'linear-gradient(135deg, #1abc9c, #16a085)', link: '/docs/skills/azure-integration-tester' },
  { title: 'Detect drift', desc: 'Continuously reconcile live Azure state against your declared intent. Propose-and-approve fixes for any difference.', icon: 'fas fa-exchange-alt', gradient: 'linear-gradient(135deg, #f39c12, #e67e22)', link: '/docs/use-cases/drift-detection' },
  { title: 'Import existing', desc: 'Reverse-engineer any resource group into IaC. Bring legacy or click-deployed infrastructure under Git-Ape governance.', icon: 'fas fa-file-import', gradient: 'linear-gradient(135deg, #e74c3c, #c0392b)', link: '/docs/use-cases/import-existing-infra' },
  { title: 'Estimate cost', desc: 'Per-resource monthly cost from live Azure retail pricing — inside the PR, before any spend commitment.', icon: 'fas fa-chart-pie', gradient: 'linear-gradient(135deg, #9b59b6, #8e44ad)', link: '/docs/use-cases/cost-estimation' },
  { title: 'Multi-environment', desc: 'One agent, dev / staging / prod with separate subscriptions, RBAC, and required-reviewer gates.', icon: 'fas fa-layer-group', gradient: 'linear-gradient(135deg, #ff6b6b, #ee5a52)', link: '/docs/use-cases/multi-environment' },
];

function UseCasesSection() {
  return (
    <section className={styles.useCasesSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          What Git-Ape does
        </Heading>
        <p className={styles.sectionSubtitle}>
          The agent is workload-agnostic — these are the things it does to <em>any</em> Azure deployment
        </p>
        <div className={styles.useCasesGrid}>
          {useCases.map((uc, i) => (
            <Link key={i} to={uc.link} className={styles.useCaseCard}>
              <div className={styles.useCaseHeader} style={{ background: uc.gradient }}>
                <i className={uc.icon} /> {uc.title}
              </div>
              <div className={styles.useCaseBody}>
                <p>{uc.desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 7: BEFORE/AFTER COMPARISON
   ========================================================================== */

const comparisons = [
  { before: 'Maintain a catalogue of 50+ Bicep / Terraform modules', after: "Ship one agent. Update its context, not 50 modules" },
  { before: 'Modules pinned to last year\u2019s API surface', after: 'Agent reads live Azure REST API specs at generation time' },
  { before: 'Compliance is a gate teams pass through at PR time', after: 'Compliance is inherent — enforced at generation, plan, and runtime' },
  { before: 'Humans translate intent into ARM / Bicep / HCL', after: 'Agent translates intent; humans approve and accept risk' },
  { before: 'Stale README files describe what modules do', after: 'Living documentation generated at conversation time' },
  { before: 'Drift detected manually, remediated weeks later', after: 'Drift detected, fix proposed, approved, applied — continuously' },
  { before: 'Audit = point-in-time review of IaC files', after: 'Audit = immutable execution trace from intent → plan → evidence' },
];

function ComparisonSection() {
  return (
    <section className={styles.comparisonSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          Module-first vs. Agents + Policy
        </Heading>
        <p className={styles.sectionSubtitle}>
          The shift the manifesto describes — and what it means for your platform team
        </p>
        <div className={styles.comparisonWrapper}>
          <div style={{
            borderRadius: '15px', overflow: 'hidden',
            boxShadow: '0 5px 20px rgba(0,0,0,0.08)',
            border: '1px solid rgba(102,126,234,0.1)',
          }}>
            {/* Headers */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
              <div style={{ background: 'linear-gradient(135deg, #e74c3c, #c0392b)', padding: '1rem 1.5rem', color: '#fff', fontWeight: 700, textAlign: 'center' }}>
                <i className="fas fa-times-circle" style={{ marginRight: '0.5rem' }} /> Module-first platform
              </div>
              <div style={{ background: 'linear-gradient(135deg, #2ecc71, #27ae60)', padding: '1rem 1.5rem', color: '#fff', fontWeight: 700, textAlign: 'center' }}>
                <i className="fas fa-check-circle" style={{ marginRight: '0.5rem' }} /> Agents + policy (Git-Ape)
              </div>
            </div>
            {/* Rows */}
            {comparisons.map((c, i) => (
              <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
                <div style={{
                  padding: '0.85rem 1.5rem', fontSize: '0.9rem',
                  borderBottom: '1px solid rgba(0,0,0,0.05)',
                  background: i % 2 === 0 ? 'rgba(231,76,60,0.03)' : 'transparent',
                }}>
                  {c.before}
                </div>
                <div style={{
                  padding: '0.85rem 1.5rem', fontSize: '0.9rem', fontWeight: 500,
                  borderBottom: '1px solid rgba(0,0,0,0.05)',
                  background: i % 2 === 0 ? 'rgba(46,204,113,0.03)' : 'transparent',
                }}>
                  {c.after}
                </div>
              </div>
            ))}
          </div>
        </div>
        <p style={{
          textAlign: 'center', marginTop: '1.5rem', fontSize: '0.9rem',
          color: 'var(--ifm-color-emphasis-600)',
        }}>
          Read the full thesis: <Link to="/docs/vision">Git-Ape Vision &amp; Manifesto</Link>{' '}
          · Original article:{' '}
          <a href="https://devblogs.microsoft.com/all-things-azure/platform-engineering-for-the-agentic-ai-era/"
             target="_blank" rel="noopener noreferrer">
            Platform Engineering for the Agentic AI Era
          </a>
        </p>
      </div>
    </section>
  );
}

/* ==========================================================================
   SECTION 8: GET STARTED CTA
   ========================================================================== */

function CtaSection() {
  return (
    <section className={styles.ctaSection}>
      <div className="container">
        <div className={styles.ctaGlass}>
          <Heading as="h2" style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '1rem' }}>
            Ready to Deploy with <span style={{ color: '#ffd700' }}>Confidence</span>?
          </Heading>
          <p style={{ fontSize: '1.1rem', opacity: 0.8, maxWidth: '550px', margin: '0 auto', lineHeight: 1.6 }}>
            Get from zero to production cloud deployments in minutes — not hours.
          </p>
          <div className={styles.ctaSteps}>
            <div className={styles.ctaStep}>
              <span className={styles.ctaStepNum}>1</span> Install Plugin
            </div>
            <div className={styles.ctaStep}>
              <span className={styles.ctaStepNum}>2</span> Connect Cloud Account
            </div>
            <div className={styles.ctaStep}>
              <span className={styles.ctaStepNum}>3</span> Deploy
            </div>
          </div>
          <div className={styles.buttons} style={{ marginTop: '2rem' }}>
            <Link className={styles.btnPrimary} to="/docs/getting-started/installation">
              <i className="fas fa-download" /> Install Now
            </Link>
            <Link className={styles.btnSecondary} to="/docs/getting-started/onboarding">
              <i className="fas fa-book-open" /> Onboarding Guide
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   PAGE LAYOUT
   ========================================================================== */

export default function Home(): ReactNode {
  return (
    <Layout
      title="Platform engineering for the agentic AI era"
      description="Git-Ape — Agents over modules. Intent over syntax. Evidence over audits. Natural-language intent in, compliant cloud deployments out, policy enforced end-to-end.">
      <HeroSection />
      <UseCasesSection />
      <TimelineSection />
      <PersonasSection />
      <CapabilitiesSection />
      <ComparisonSection />
      <VideoSection />
      <CtaSection />
    </Layout>
  );
}
