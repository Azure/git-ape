import React from 'react';

interface MetricCardProps {
  value: string;
  label: string;
  icon?: string;
}

const styles = {
  card: {
    textAlign: 'center' as const,
    padding: '2rem 1.5rem',
    borderRadius: '15px',
    background: 'rgba(255, 255, 255, 0.05)',
    backdropFilter: 'blur(10px)',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
    cursor: 'default',
  },
  icon: {
    fontSize: '1.5rem',
    marginBottom: '0.5rem',
    opacity: 0.7,
  },
  value: {
    fontSize: '2.8rem',
    fontWeight: 800,
    color: '#ffd700',
    lineHeight: 1.1,
    marginBottom: '0.3rem',
  },
  label: {
    fontSize: '0.85rem',
    fontWeight: 600,
    textTransform: 'uppercase' as const,
    letterSpacing: '0.08em',
    opacity: 0.8,
  },
};

export default function MetricCard({ value, label, icon }: MetricCardProps): React.ReactElement {
  return (
    <div
      className="ga-card-hover"
      style={styles.card}
      onMouseEnter={(e) => {
        (e.currentTarget as HTMLElement).style.transform = 'translateY(-5px)';
        (e.currentTarget as HTMLElement).style.boxShadow = '0 10px 30px rgba(0,0,0,0.2)';
      }}
      onMouseLeave={(e) => {
        (e.currentTarget as HTMLElement).style.transform = 'translateY(0)';
        (e.currentTarget as HTMLElement).style.boxShadow = 'none';
      }}
    >
      {icon && <div style={styles.icon}><i className={icon} /></div>}
      <div style={styles.value}>{value}</div>
      <div style={styles.label}>{label}</div>
    </div>
  );
}
