import React from 'react';

interface ComparisonTableProps {
  before: { title: string; items: string[] };
  after: { title: string; items: string[] };
}

export default function ComparisonTable({ before, after }: ComparisonTableProps): React.ReactElement {
  const maxLen = Math.max(before.items.length, after.items.length);

  return (
    <div style={{
      borderRadius: '15px',
      overflow: 'hidden',
      boxShadow: '0 5px 15px rgba(0,0,0,0.08)',
      margin: '2rem 0',
      border: '1px solid rgba(102, 126, 234, 0.1)',
    }}>
      <div style={{
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
      }}>
        <div style={{
          background: 'linear-gradient(135deg, #e74c3c, #c0392b)',
          padding: '1rem 1.5rem',
          color: '#fff',
          fontWeight: 700,
          fontSize: '1rem',
          textAlign: 'center',
        }}>
          <i className="fas fa-times-circle" style={{ marginRight: '0.5rem' }} />
          {before.title}
        </div>
        <div style={{
          background: 'linear-gradient(135deg, #2ecc71, #27ae60)',
          padding: '1rem 1.5rem',
          color: '#fff',
          fontWeight: 700,
          fontSize: '1rem',
          textAlign: 'center',
        }}>
          <i className="fas fa-check-circle" style={{ marginRight: '0.5rem' }} />
          {after.title}
        </div>
        {Array.from({ length: maxLen }).map((_, i) => (
          <React.Fragment key={i}>
            <div style={{
              padding: '0.85rem 1.5rem',
              borderBottom: '1px solid rgba(0,0,0,0.05)',
              background: i % 2 === 0 ? 'rgba(231, 76, 60, 0.03)' : 'transparent',
              fontSize: '0.9rem',
            }}>
              {before.items[i] || '—'}
            </div>
            <div style={{
              padding: '0.85rem 1.5rem',
              borderBottom: '1px solid rgba(0,0,0,0.05)',
              background: i % 2 === 0 ? 'rgba(46, 204, 113, 0.03)' : 'transparent',
              fontSize: '0.9rem',
              fontWeight: 500,
            }}>
              {after.items[i] || '—'}
            </div>
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
