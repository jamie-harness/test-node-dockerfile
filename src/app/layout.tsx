import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Next.js Docker App',
  description: 'A Next.js application running in Docker',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}

