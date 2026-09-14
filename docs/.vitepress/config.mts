import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Godot Swift Plugin',
  description: 'Toolkit for developing native Godot iOS/Apple plugins using pure Swift',
  base: '/',
  cleanUrls: true,
  themeConfig: {
    logo: '/icon.svg',
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Signals', link: '/guide/signals' },
      { text: 'Android Parity', link: '/guide/android-parity' },
      { text: 'GitHub', link: 'https://github.com/Poing-Studios/godot-swift-plugin' }
    ],
    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/guide/introduction' },
          { text: 'Quickstart', link: '/guide/getting-started' },
          { text: 'Architecture & Lifecycle', link: '/guide/architecture' }
        ]
      },
      {
        text: 'API & Core Concepts',
        items: [
          { text: 'Exposing Methods (@objc)', link: '/guide/methods' },
          { text: 'Signals & Events', link: '/guide/signals' },
          { text: 'Android vs. iOS Parity', link: '/guide/android-parity' }
        ]
      },
      {
        text: 'Godot Integration',
        items: [
          { text: 'GDExtension Setup', link: '/guide/gdextension-setup' },
          { text: 'Sample & Testbed', link: '/guide/sample-project' }
        ]
      }
    ],
    search: {
      provider: 'local'
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Poing-Studios/godot-swift-plugin' }
    ],
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2026-present Poing Studios'
    }
  }
})
