export default function Home() {
  return (
    <main style={{ 
      display: 'flex', 
      flexDirection: 'column', 
      alignItems: 'center', 
      justifyContent: 'center', 
      minHeight: '100vh',
      fontFamily: 'system-ui, sans-serif'
    }}>
      <h1>Hello from Next.js in Docker!</h1>
      <p>Build Info:</p>
      <ul>
        <li>GIT_COMMIT: {process.env.GIT_COMMIT || 'N/A'}</li>
        <li>BUILD_DATE: {process.env.BUILD_DATE || 'N/A'}</li>
        <li>NODE_ENV: {process.env.NODE_ENV}</li>
      </ul>
    </main>
  )
}

