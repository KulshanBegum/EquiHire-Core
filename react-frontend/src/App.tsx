import { useAuthContext } from "@asgardeo/auth-react";
import LandingPage from './pages/landing/Landing';
import Dashboard from './pages/dashboard/Dashboard';
import CandidateWelcome from './pages/candidate/Welcome';
import CandidateInterview from './pages/candidate/Interview';

function App() {
  const { state } = useAuthContext();

  // Simple routing for Candidate Pages (MVP)
  // In a real app, use react-router-dom
  const path = window.location.pathname;

  if (path === '/candidate/welcome') {
    return <CandidateWelcome />;
  }
  if (path === '/candidate/interview') {
    return <CandidateInterview />;
  }

  return (
    <>
      {state.isAuthenticated ? <Dashboard /> : <LandingPage />}
    </>
  )
}

export default App
