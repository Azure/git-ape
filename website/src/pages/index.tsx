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
          Deploy Cloud with{' '}
          <span className={styles.heroGold}>Git-Ape</span>
        </Heading>
        <p className={styles.heroSubtitle}>
          The intelligent multi-agent system for GitHub Copilot that handles
          cloud deployments end-to-end — from requirements to production,
          with security gates at every step.
        </p>
        <div className={styles.buttons}>
          <Link className={styles.btnPrimary} to="/docs/intro">
            <i className="fas fa-rocket" /> Get Started
          </Link>
          <Link className={styles.btnSecondary} to="/docs/agents/overview">
            <i className="fas fa-robot" /> Explore Agents
          </Link>
        </div>
      </div>
    </header>
  );
}

/* ==========================================================================
   SECTION 2: IMPACT METRICS
   ========================================================================== */

const metrics = [
  { value: '8', label: 'AI Agents', icon: 'fas fa-robot' },
  { value: '13', label: 'Skills', icon: 'fas fa-wrench' },
  { value: '4', label: 'CI/CD Workflows', icon: 'fas fa-code-branch' },
  { value: '5', label: 'WAF Pillars', icon: 'fas fa-shield-alt' },
  { value: '15+', label: 'Resource Types', icon: 'fas fa-cloud' },
  { value: '100%', label: 'Security Gate', icon: 'fas fa-lock' },
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
  { title: 'Serverless API', desc: 'Deploy Function Apps with Storage, App Insights, and managed identities.', icon: 'fas fa-bolt', gradient: 'linear-gradient(135deg, #667eea, #764ba2)', link: '/docs/use-cases/deploy-function-app' },
  { title: 'Web App + SQL', desc: 'Full-stack web application with SQL Database and Key Vault secrets.', icon: 'fas fa-globe', gradient: 'linear-gradient(135deg, #2ecc71, #27ae60)', link: '/docs/use-cases/deploy-web-app-sql' },
  { title: 'Container Apps', desc: 'Container Apps with Registry, Log Analytics, and auto-scaling.', icon: 'fas fa-docker', gradient: 'linear-gradient(135deg, #3498db, #2980b9)', link: '/docs/use-cases/deploy-container-app' },
  { title: 'Import Existing', desc: 'Reverse-engineer deployed cloud resources into IaC templates.', icon: 'fas fa-file-import', gradient: 'linear-gradient(135deg, #f39c12, #e67e22)', link: '/docs/use-cases/import-existing-infra' },
  { title: 'Cost Analysis', desc: 'Estimate costs per resource before deploying using retail pricing.', icon: 'fas fa-chart-pie', gradient: 'linear-gradient(135deg, #e74c3c, #c0392b)', link: '/docs/use-cases/cost-estimation' },
  { title: 'CI/CD Pipeline', desc: 'Full lifecycle with plan-on-PR, deploy-on-merge, and destroy flows.', icon: 'fas fa-code-branch', gradient: 'linear-gradient(135deg, #9b59b6, #8e44ad)', link: '/docs/use-cases/cicd-pipeline' },
];

function UseCasesSection() {
  return (
    <section className={styles.useCasesSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          Use Cases
        </Heading>
        <p className={styles.sectionSubtitle}>
          Real-world deployment patterns powered by Git-Ape
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
  { before: 'Manually write ARM templates from scratch', after: 'AI-generated templates from natural language' },
  { before: 'Hope you remembered security best practices', after: 'Blocking security gate — 100% enforced' },
  { before: 'Guess at naming conventions each time', after: 'Platform-compliant naming via naming research skills' },
  { before: 'Discover cost surprises after deployment', after: 'Real-time cost estimation before deploying' },
  { before: 'Manual drift detection (if at all)', after: 'Automated drift detection with reconciliation' },
  { before: 'Siloed knowledge across team members', after: 'Living documentation auto-generated from source' },
];

function ComparisonSection() {
  return (
    <section className={styles.comparisonSection}>
      <div className="container">
        <Heading as="h2" className={clsx(styles.sectionTitle, 'ga-gradient-text')}>
          Before &amp; After Git-Ape
        </Heading>
        <p className={styles.sectionSubtitle}>
          See how Git-Ape transforms cloud deployment workflows
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
                <i className="fas fa-times-circle" style={{ marginRight: '0.5rem' }} /> Without Git-Ape
              </div>
              <div style={{ background: 'linear-gradient(135deg, #2ecc71, #27ae60)', padding: '1rem 1.5rem', color: '#fff', fontWeight: 700, textAlign: 'center' }}>
                <i className="fas fa-check-circle" style={{ marginRight: '0.5rem' }} /> With Git-Ape
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
      title="Intelligent Cloud Deployment Agents"
      description="Git-Ape — The intelligent multi-agent system for GitHub Copilot that handles cloud deployments end-to-end — with security gates at every step.">
      <HeroSection />
      <MetricsSection />
      <PersonasSection />
      <TimelineSection />
      <CapabilitiesSection />
      <UseCasesSection />
      <ComparisonSection />
      <CtaSection />
    </Layout>
  );
}
