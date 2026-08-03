import type { Metadata } from 'next'
import { Source_Serif_4, Inter } from 'next/font/google'
import './globals.css'

const display = Source_Serif_4({ variable: '--font-display', subsets: ['latin'], display: 'swap' })
const body = Inter({ variable: '--font-body', subsets: ['latin'], display: 'swap' })

export const metadata: Metadata = {
  title: {
    default: 'GHCBA Member Dashboard',
    template: '%s · GHCBA',
  },
  description: 'Guwahati High Court Bar Association — member dashboard.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  )
}
