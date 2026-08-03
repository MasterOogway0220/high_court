import type { Metadata } from 'next'
import { Spectral, IBM_Plex_Sans, IBM_Plex_Mono } from 'next/font/google'
import './globals.css'

// Spectral for display: a documentary serif with flared, slightly severe serifs —
// formal without the high-contrast fashion serif look that any brief would get.
const display = Spectral({
  variable: '--font-spectral',
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  display: 'swap',
})

// Plex Sans and Plex Mono as a matched pair: an institutional records system reads
// as one family, and the mono carries every number that identifies a record.
const sans = IBM_Plex_Sans({
  variable: '--font-plex-sans',
  subsets: ['latin'],
  weight: ['400', '500', '600'],
  display: 'swap',
})

const mono = IBM_Plex_Mono({
  variable: '--font-plex-mono',
  subsets: ['latin'],
  weight: ['400', '500'],
  display: 'swap',
})

export const metadata: Metadata = {
  title: {
    default: 'Guwahati High Court Bar Association',
    template: '%s · Guwahati High Court Bar Association',
  },
  description: 'Member dashboard of the Guwahati High Court Bar Association.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${display.variable} ${sans.variable} ${mono.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  )
}
