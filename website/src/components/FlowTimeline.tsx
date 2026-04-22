import React from 'react';

interface TimelineStep {
  title: string;
  description: string;
  icon?: string;
  badge?: string;
}

interface FlowTimelineProps {
  steps: TimelineStep[];
}

export default function FlowTimeline({ steps }: FlowTimelineProps): React.ReactElement {
  return (
    <div style={{ position: 'relative', padding: '2rem 0', margin: '2rem 0' }}>
      <div style={{
        position: 'absolute',
        left: '28px',
        top: '2rem',
        bottom: '2rem',
        width: '3px',
        background: 'linear-gradient(to bottom, #667eea, #764ba2, #ffd700)',
        borderRadius: '2px',
      }} />
      {steps.map((step, index) => (
        <div
          key={index}
          style={{
            display: 'flex',
            gap: '1.5rem',
            marginBottom: '2rem',
            position: 'relative',
            animation: `fadeInUp 0.5s ease-out ${index * 0.1}s both`,
          }}
        >
          <div style={{
            width: '56px',
            height: '56px',
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #667eea, #764ba2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            color: '#fff',
            fontWeight: 800,
            fontSize: step.icon ? '1.2rem' : '1rem',
            boxShadow: '0 4px 15px rgba(102, 126, 234, 0.3)',
            zIndex: 1,
          }}>
            {step.icon ? <i className={step.icon} /> : index + 1}
          </div>
          <div
            className="ga-card-hover"
            style={{
              flex: 1,
              padding: '1.25rem 1.5rem',
              borderRadius: '12px',
              background: 'var(--ifm-background-surface-color, #fff)',
              border: '1px solid rgba(102, 126, 234, 0.1)',
              boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLElement).style.boxShadow = '0 5px 15px rgba(0,0,0,0.1)';
              (e.currentTarget as HTMLElement).style.borderColor = '#667eea';
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLElement).style.boxShadow = '0 2px 8px rgba(0,0,0,0.06)';
              (e.currentTarget as HTMLElement).style.borderColor = 'rgba(102, 126, 234, 0.1)';
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
              <h4 style={{ margin: 0, fontWeight: 700, fontSize: '1.05rem' }}>{step.title}</h4>
              {step.badge && (
                <span style={{
                  fontSize: '0.7rem',
                  fontWeight: 600,
                  padding: '0.15rem 0.6rem',
                  borderRadius: '20px',
                  background: 'linear-gradient(135deg, #667eea, #764ba2)',
                  color: '#fff',
                  letterSpacing: '0.03em',
                }}>
                  {step.badge}
                </span>
              )}
            </div>
            <p style={{ margin: 0, fontSize: '0.9rem', opacity: 0.8, lineHeight: 1.6 }}>
              {step.description}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
