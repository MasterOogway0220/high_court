import type { Metadata } from 'next'
import { Plus_Jakarta_Sans } from 'next/font/google'
import './globals.css'

// One family for everything, as the reference does: Plus Jakarta Sans carries the
// wordmark at 800, headings at 700, labels at 600 and body at 400/500.
const jakarta = Plus_Jakarta_Sans({
  variable: '--font-jakarta',
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800'],
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
    <html lang="en" className={`${jakarta.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  )
}
