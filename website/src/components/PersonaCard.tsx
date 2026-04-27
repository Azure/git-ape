import React from 'react';

interface PersonaCardProps {
  title: string;
  icon: string;
  description: string;
  link?: string;
  color?: string;
}

export default function PersonaCard({ title, icon, description, link, color = '#667eea' }: PersonaCardProps): React.ReactElement {
  const card = (
    <div
      className="ga-card-hover"
      style={{
        padding: '2rem',
        borderRadius: '15px',
        background: 'var(--ifm-background-surface-color, #fff)',
        border: '1px solid rgba(102, 126, 234, 0.1)',
        boxShadow: '0 5px 15px rgba(0,0,0,0.08)',
        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        height: '100%',
        display: 'flex',
        flexDirection: 'column' as const,
        position: 'relative' as const,
        overflow: 'hidden',
      }}
      onMouseEnter={(e) => {
        (e.currentTarget as HTMLElement).style.transform = 'translateY(-5px)';
        (e.currentTarget as HTMLElement).style.boxShadow = '0 10px 30px rgba(0,0,0,0.12)';
        (e.currentTarget as HTMLElement).style.borderColor = color;
      }}
      onMouseLeave={(e) => {
        (e.currentTarget as HTMLElement).style.transform = 'translateY(0)';
        (e.currentTarget as HTMLElement).style.boxShadow = '0 5px 15px rgba(0,0,0,0.08)';
        (e.currentTarget as HTMLElement).style.borderColor = 'rgba(102, 126, 234, 0.1)';
      }}
    >
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: '4px',
        background: `linear-gradient(135deg, ${color}, #764ba2)`,
      }} />
      <div style={{
        fontSize: '2.5rem',
        marginBottom: '1rem',
        width: '60px',
        height: '60px',
        borderRadius: '15px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: `${color}15`,
      }}>
        <i className={icon} style={{ color }} />
      </div>
      <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '0.75rem' }}>{title}</h3>
      <p style={{ fontSize: '0.95rem', opacity: 0.8, lineHeight: 1.6, flex: 1 }}>{description}</p>
      {link && (
        <div style={{ marginTop: '1rem', fontWeight: 600, color, fontSize: '0.9rem' }}>
          Learn more →
        </div>
      )}
    </div>
  );

  if (link) {
    return <a href={link} style={{ textDecoration: 'none', color: 'inherit', display: 'block', height: '100%' }}>{card}</a>;
  }

  return card;
}
