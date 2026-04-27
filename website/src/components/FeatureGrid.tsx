import React from 'react';

interface FeatureGridProps {
  children: React.ReactNode;
  columns?: 2 | 3 | 4;
  gap?: string;
}

export default function FeatureGrid({ children, columns = 3, gap = '1.5rem' }: FeatureGridProps): React.ReactElement {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${columns}, 1fr)`,
        gap,
        margin: '2rem 0',
      }}
      className="ga-feature-grid"
    >
      {children}
      <style>{`
        @media (max-width: 996px) {
          .ga-feature-grid {
            grid-template-columns: repeat(2, 1fr) !important;
          }
        }
        @media (max-width: 576px) {
          .ga-feature-grid {
            grid-template-columns: 1fr !important;
          }
        }
      `}</style>
    </div>
  );
}
