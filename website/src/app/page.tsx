import Link from "next/link";
import styles from "./page.module.css";
import ScrollReveal from "@/components/ScrollReveal";

export default function Home() {
  return (
    <main className={styles.main}>
      {/* Hero Section */}
      <section className={styles.hero}>
        <ScrollReveal>
          <div className={styles.heroContent}>
            <h1 className={styles.heroTitle}>
              Share Moments.<br />
              <span className="text-gradient">Connect with People.</span>
            </h1>
            <p className={styles.heroSubtitle}>
              KnockPost is the premium social media platform designed for creators,
              photographers, and everyday users who value authentic connections and meaningful content.
            </p>
            <div className={styles.heroActions}>
              <Link href="/signup" className={styles.primaryBtn}>
                Join the Community
              </Link>
              <Link href="#features" className={styles.secondaryBtn}>
                Explore Features
              </Link>
            </div>
          </div>
        </ScrollReveal>
        
        <ScrollReveal delay={200}>
          <div className={styles.heroImageContainer}>
            <div className={`${styles.mockupCard} glass`}>
              {/* Placeholder for actual mobile mockup */}
              <div className={styles.mockupContent}>
                <div className={styles.mockupHeader}>
                  <div className={styles.mockupAvatar}></div>
                  <div className={styles.mockupUsername}></div>
                </div>
                <div className={styles.mockupImage}></div>
                <div className={styles.mockupActions}></div>
              </div>
            </div>
          </div>
        </ScrollReveal>
      </section>

      {/* Features Section */}
      <section id="features" className={styles.features}>
        <ScrollReveal>
          <h2 className={styles.sectionTitle}>Everything you need to connect</h2>
        </ScrollReveal>
        <div className={styles.featuresGrid}>
          <ScrollReveal delay={100}>
            <div className={`${styles.featureCard} glass`}>
              <h3>Share Photos</h3>
              <p>Upload high-quality images and share your everyday moments with friends and followers.</p>
            </div>
          </ScrollReveal>
          <ScrollReveal delay={200}>
            <div className={`${styles.featureCard} glass`}>
              <h3>Waves</h3>
              <p>Experience an immersive, infinite feed of short-form videos to discover trending content.</p>
            </div>
          </ScrollReveal>
          <ScrollReveal delay={300}>
            <div className={`${styles.featureCard} glass`}>
              <h3>Communities</h3>
              <p>Join or create dedicated spaces for your passions, hobbies, and interests.</p>
            </div>
          </ScrollReveal>
        </div>
      </section>

      {/* Why KnockPost Section */}
      <section className={styles.whySection}>
        <ScrollReveal>
          <div className={styles.whyContent}>
            <h2 className={styles.sectionTitle}>Focus on what matters</h2>
            <p className={styles.sectionSubtitle}>
              We built KnockPost to prioritize authentic sharing and community engagement over addictive algorithms. 
              Experience a cleaner, faster, and more beautiful way to connect.
            </p>
            <ul className={styles.whyList}>
              <li>✨ Minimalist, premium design</li>
              <li>🚀 Lightning-fast performance</li>
              <li>🛡️ Strong privacy and user safety</li>
              <li>🎨 Total creative freedom</li>
            </ul>
          </div>
        </ScrollReveal>
      </section>

      {/* CTA Section */}
      <section className={styles.ctaSection}>
        <ScrollReveal>
          <div className={`${styles.ctaContainer} glass`}>
            <h2>Ready to get started?</h2>
            <p>Download the KnockPost app today and join thousands of creators.</p>
            <div className={styles.ctaActions}>
              <button className={styles.storeBtn}>Download for iOS</button>
              <button className={styles.storeBtn}>Download for Android</button>
            </div>
          </div>
        </ScrollReveal>
      </section>
    </main>
  );
}
