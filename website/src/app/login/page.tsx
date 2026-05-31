"use client";

import { useState } from "react";
import Link from "next/link";
import styles from "./login.module.css";
// import { auth } from "@/lib/firebase";
// import { signInWithEmailAndPassword } from "firebase/auth";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      // await signInWithEmailAndPassword(auth, email, password);
      // Redirect to /feed
      window.location.href = "/feed";
    } catch (err: any) {
      setError(err.message || "Failed to log in");
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.loginBox}>
        <h1 className={styles.logo}>KnockPost</h1>
        <form onSubmit={handleLogin} className={styles.form}>
          <input
            type="email"
            placeholder="Email address"
            className={styles.input}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <input
            type="password"
            placeholder="Password"
            className={styles.input}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          {error && <p className={styles.error}>{error}</p>}
          <button type="submit" className={styles.loginBtn}>
            Log In
          </button>
        </form>
        <div className={styles.divider}>
          <div className={styles.line}></div>
          <span>OR</span>
          <div className={styles.line}></div>
        </div>
        <Link href="/forgot-password" className={styles.forgotPassword}>
          Forgot password?
        </Link>
      </div>
      <div className={styles.signupBox}>
        <p>
          Don't have an account? <Link href="/signup" className={styles.signupLink}>Sign up</Link>
        </p>
      </div>
    </div>
  );
}
