import { Metadata, ResolvingMetadata } from "next";
import styles from "./profile.module.css";
// import { db } from "@/lib/firebase"; // Assuming we would use this to fetch data
// import { collection, query, where, getDocs } from "firebase/firestore";

type Props = {
  params: Promise<{ username: string }>;
};

// Generate dynamic OpenGraph metadata for SEO
export async function generateMetadata(
  { params }: Props,
  parent: ResolvingMetadata
): Promise<Metadata> {
  const resolvedParams = await params;
  const username = resolvedParams.username.replace("%40", "@"); // handle @ symbol in URL
  
  // In a real implementation, fetch user from Firestore:
  // const q = query(collection(db, "users"), where("username", "==", username));
  // const querySnapshot = await getDocs(q);
  // const user = querySnapshot.docs[0]?.data();
  
  // Mock data for preview purposes
  const title = `${username} on KnockPost`;
  const description = `Check out ${username}'s profile, posts, and communities on KnockPost.`;

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: "profile",
      url: `https://knockpost.com/${username}`,
      siteName: "KnockPost",
      images: [
        {
          url: "https://knockpost.com/mockups/default-avatar.png", // Replace with user.profileImageUrl
          width: 800,
          height: 800,
          alt: `${username}'s avatar`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: ["https://knockpost.com/mockups/default-avatar.png"],
    },
  };
}

export default async function ProfilePage({ params }: Props) {
  const resolvedParams = await params;
  const username = resolvedParams.username.replace("%40", "@");
  
  return (
    <div className={styles.container}>
      <div className={`${styles.profileCard} glass`}>
        <div className={styles.avatar}></div>
        <h1 className={styles.name}>User Profile</h1>
        <p className={styles.username}>{username}</p>
        <p className={styles.bio}>
          This is a public profile preview. Download the KnockPost app to see their full profile, posts, and waves!
        </p>
        <div className={styles.stats}>
          <div className={styles.stat}>
            <span className={styles.statValue}>--</span>
            <span className={styles.statLabel}>Followers</span>
          </div>
          <div className={styles.stat}>
            <span className={styles.statValue}>--</span>
            <span className={styles.statLabel}>Following</span>
          </div>
          <div className={styles.stat}>
            <span className={styles.statValue}>--</span>
            <span className={styles.statLabel}>Posts</span>
          </div>
        </div>
        <button className={styles.downloadBtn}>Open in KnockPost App</button>
      </div>
    </div>
  );
}
