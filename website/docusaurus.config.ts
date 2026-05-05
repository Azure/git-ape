import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const baseUrl =
  process.env.DOCUSAURUS_BASE_URL ??
  (process.env.NODE_ENV === 'development' ? '/' : '/git-ape/');

const config: Config = {
  title: 'Git-Ape',
  tagline: 'Platform engineering for the agentic AI era — agents over modules, intent over syntax, evidence over audits',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://azure.github.io',
  baseUrl,

  organizationName: 'Azure',
  projectName: 'git-ape',
  trailingSlash: false,

  onBrokenLinks: 'throw',

  markdown: {
    mermaid: true,
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  themes: ['@docusaurus/theme-mermaid'],

  clientModules: [require.resolve('./src/clientModules/mermaidZoom.ts')],

  stylesheets: [
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css',
    'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap',
  ],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/Azure/git-ape/edit/main/website/',
          lastVersion: 'current',
          versions: {
            current: {
              label: 'Next',
              path: '',
            },
          },
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/git-ape-social-card.png',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    announcementBar: {
      id: 'experimental_notice',
      content: '🚀 Git-Ape is experimental — <a href="https://github.com/Azure/git-ape/issues">feedback welcome</a>!',
      backgroundColor: '#667eea',
      textColor: '#fff',
      isCloseable: true,
    },
    navbar: {
      title: 'Git-Ape',
      logo: {
        alt: 'Git-Ape Logo',
        src: 'img/logo.png',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          to: '/docs/personas/for-executives',
          label: 'Who Is This For?',
          position: 'left',
        },
        {
          to: '/docs/use-cases/deploy-anything',
          label: 'What it does',
          position: 'left',
        },
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/Azure/git-ape',
          position: 'right',
          className: 'header-github-link',
          'aria-label': 'GitHub repository',
          html: '<i class="fab fa-github" style="font-size: 1.3rem;"></i>',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            { label: 'Getting Started', to: '/docs/intro' },
            { label: 'Agents', to: '/docs/agents/overview' },
            { label: 'Skills', to: '/docs/skills/overview' },
          ],
        },
        {
          title: 'Resources',
          items: [
            { label: 'GitHub Repository', href: 'https://github.com/Azure/git-ape' },
            { label: 'microsoft/hve-core', href: 'https://github.com/microsoft/hve-core' },
            { label: 'microsoft/azure-skills', href: 'https://github.com/microsoft/azure-skills' },
            { label: 'Azure Cloud Adoption Framework', href: 'https://learn.microsoft.com/azure/cloud-adoption-framework/' },
            { label: 'License (MIT)', href: 'https://github.com/Azure/git-ape/blob/main/LICENSE' },
          ],
        },
        {
          title: 'Security',
          items: [
            { label: 'Security Policy', href: 'https://github.com/Azure/git-ape/blob/main/SECURITY.md' },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Microsoft. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json', 'yaml'],
    },
    mermaid: {
      theme: { light: 'neutral', dark: 'dark' },
    },
  } satisfies Preset.ThemeConfig,
};

export default config;

