  import React, { useState } from "react";

export default function Login({ onLogin }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!email || !password) {
      setError("Please enter both email and password.");
      return;
    }
    setError("");
    onLogin();
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden" 
         style={{ 
           background: "linear-gradient(135deg, rgb(0, 2, 73) 0%, rgb(15, 67, 146) 30%, rgb(220, 38, 38) 70%, rgb(185, 28, 28) 100%)"
         }}>
      <div className="relative z-10 w-full max-w-md px-6">
        {/* Main login card */}
        <div className="bg-white/10 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/20 p-8">
          {/* Logo and header */}
          <div className="text-center mb-8">
            <div className="inline-flex items-center justify-center w-40 h-40 mb-4 overflow-hidden">
              <img
                src={`${process.env.PUBLIC_URL}/Resme LOGO..png`}
                alt="ResMe logo"
                className="w-full h-full object-contain"
              />
            </div>
            <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight mb-2 bg-gradient-to-r from-red-300 via-white to-blue-300 text-transparent bg-clip-text">ResMe</h1>
            <p className="text-red-100 text-sm font-medium">Admin Dashboard</p>
          </div>

          {/* Login form */}
          <form className="space-y-6" onSubmit={handleSubmit}>
            {/* Email field */}
            <div className="space-y-2">
              <label className="text-white text-sm font-medium">Email Address</label>
              <div className="relative">
                <input
                  type="email"
                  className="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-red-200 focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-transparent transition-all duration-200"
                  placeholder="Enter you email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  autoComplete="username"
                />
                <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                  <svg className="h-5 w-5 text-red-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
                  </svg>
                </div>
              </div>
            </div>

            {/* Password field */}
            <div className="space-y-2">
              <label className="text-white text-sm font-medium">Password</label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  className="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-red-200 focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-transparent transition-all duration-200 pr-12"
                  placeholder="Enter your password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-red-200 hover:text-white transition-colors duration-200"
                  onClick={() => setShowPassword(v => !v)}
                  tabIndex={-1}
                >
                  {showPassword ? (
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  ) : (
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.542-7a9.956 9.956 0 012.223-3.592M6.7 6.7A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.542 7a9.97 9.97 0 01-4.304 5.377M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 3l18 18" />
                    </svg>
                  )}
                </button>
              </div>
            </div>

            {/* Error message */}
            {error && (
              <div className="bg-red-500/20 border border-red-400/30 rounded-lg px-4 py-3">
                <div className="flex items-center">
                  <svg className="h-5 w-5 text-red-200 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-red-200 text-sm font-medium">{error}</span>
                </div>
              </div>
            )}

            {/* Submit button */}
            <button 
              type="submit" 
              className="w-full bg-gradient-to-r from-red-600 to-red-700 text-white py-3 px-4 rounded-xl font-semibold hover:from-red-700 hover:to-red-800 transform hover:scale-[1.02] transition-all duration-200 shadow-lg hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-red-400 focus:ring-offset-2 focus:ring-offset-transparent"
            >
              Sign In
            </button>
          </form>

          {/* Footer links */}
          <div className="mt-8 pt-6 border-t border-white/10">
            <div className="flex items-center justify-between text-sm">
              <button className="text-red-200 hover:text-white transition-colors duration-200 font-medium">
                Forgot password?
              </button>
              <button className="text-red-200 hover:text-white transition-colors duration-200 font-medium">
                Need help?
              </button>
            </div>
          </div>
        </div>

        
      </div>
    </div>
  );
} 