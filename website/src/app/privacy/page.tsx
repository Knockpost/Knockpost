import styles from "./privacy.module.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy | KnockPost",
  description: "Learn how KnockPost collects, uses, and protects your information.",
};

export default function PrivacyPolicy() {
  return (
    <div className={styles.container}>
      <h1 className={styles.title}>Privacy Policy</h1>
      <div className={styles.lastUpdated}>Last Updated: May 24, 2026<br />Version: 1.0</div>

      <p className={styles.paragraph}>
        Welcome to KnockPost. This Privacy Policy explains how KnockPost collects, uses, stores, and protects user
        information when using the KnockPost platform and related services.
      </p>

      <h2 className={styles.heading2}>1. Information We Collect</h2>
      <p className={styles.paragraph}>We may collect:</p>
      <ul className={styles.list}>
        <li>Name</li>
        <li>Username</li>
        <li>Email address</li>
        <li>Profile photo</li>
        <li>Posts, Waves, Glimpse, comments, reactions, and messages</li>
        <li>Device and usage information</li>
        <li>App interaction data</li>
      </ul>

      <h2 className={styles.heading2}>2. How We Use Information</h2>
      <p className={styles.paragraph}>We use collected information to:</p>
      <ul className={styles.list}>
        <li>Create and manage accounts</li>
        <li>Improve platform functionality</li>
        <li>Personalize user experience</li>
        <li>Prevent spam and abuse</li>
        <li>Maintain security and stability</li>
        <li>Send notifications and updates</li>
      </ul>

      <h2 className={styles.heading2}>3. User Content</h2>
      <p className={styles.paragraph}>
        Users are responsible for the posts, Waves, Glimpse, and uploaded content they share or share on KnockPost.
      </p>
      <p className={styles.paragraph}>Users must not upload:</p>
      <ul className={styles.list}>
        <li>Illegal content</li>
        <li>Copyrighted material without permission</li>
        <li>Hate speech</li>
        <li>Harassment or threats</li>
        <li>Malware or harmful links</li>
      </ul>
      <p className={styles.paragraph}>KnockPost reserves the right to remove content that violates policies.</p>

      <h2 className={styles.heading2}>4. Third-Party Services</h2>
      <p className={styles.paragraph}>KnockPost may use:</p>
      <ul className={styles.list}>
        <li>Firebase Authentication</li>
        <li>Firebase Firestore</li>
        <li>Firebase Storage</li>
        <li>Firebase Cloud Messaging</li>
        <li>Firebase Analytics</li>
        <li>Firebase Crashlytics</li>
      </ul>
      <p className={styles.paragraph}>Third-party services may process certain data required for platform functionality.</p>

      <h2 className={styles.heading2}>5. Data Security</h2>
      <p className={styles.paragraph}>
        KnockPost uses reasonable security measures to protect user data. However, no internet transmission or
        electronic storage method is completely secure.
      </p>

      <h2 className={styles.heading2}>6. Account Deletion</h2>
      <p className={styles.paragraph}>Users may request account deletion through app settings.</p>
      <p className={styles.paragraph}>
        Some information may be temporarily retained for legal, security, or abuse-prevention purposes.
      </p>

      <h2 className={styles.heading2}>7. Children&apos;s Privacy</h2>
      <p className={styles.paragraph}>KnockPost is not intended for users under 13 years old.</p>

      <h2 className={styles.heading2}>8. Community Safety</h2>
      <p className={styles.paragraph}>
        Users engaging in harassment, spam, impersonation, fraud, or harmful activity may face restrictions or
        permanent suspension.
      </p>

      <h2 className={styles.heading2}>9. Intellectual Property</h2>
      <p className={styles.paragraph}>Users retain ownership of their content.</p>
      <p className={styles.paragraph}>
        By posting on KnockPost, users grant KnockPost permission to host, display, and distribute posts, Waves,
        Glimpse, and uploaded content for platform functionality.
      </p>

      <h2 className={styles.heading2}>10. Policy Changes</h2>
      <p className={styles.paragraph}>KnockPost may update this Privacy Policy periodically.</p>
      <p className={styles.paragraph}>Continued use of the platform means acceptance of updated policies.</p>

      <h2 className={styles.heading2}>11. Contact</h2>
      <p className={styles.paragraph}>
        Users may contact KnockPost through official support channels for policy-related concerns.
      </p>
    </div>
  );
}
