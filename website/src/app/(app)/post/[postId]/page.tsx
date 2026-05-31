import { Metadata, ResolvingMetadata } from "next";
import styles from "./post.module.css";
// import { db } from "@/lib/firebase"; 
// import { doc, getDoc } from "firebase/firestore";

type Props = {
  params: Promise<{ postId: string }>;
};

// Generate dynamic OpenGraph metadata for SEO
export async function generateMetadata(
  { params }: Props,
  parent: ResolvingMetadata
): Promise<Metadata> {
  const resolvedParams = await params;
  const postId = resolvedParams.postId;
  
  // In a real implementation, fetch post from Firestore:
  // const postSnap = await getDoc(doc(db, "posts", postId));
  // const post = postSnap.data();
  
  // Mock data for preview purposes
  const title = `A Post on KnockPost`;
  const description = `Check out this amazing post and join the conversation on KnockPost.`;

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: "article",
      url: `https://knockpost.com/post/${postId}`,
      siteName: "KnockPost",
      images: [
        {
          url: "https://knockpost.com/mockups/default-post.png", // Replace with post.mediaUrl
          width: 1200,
          height: 630,
          alt: `KnockPost Shared Media`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: ["https://knockpost.com/mockups/default-post.png"],
    },
  };
}

export default async function PostPage({ params }: Props) {
  const resolvedParams = await params;
  const postId = resolvedParams.postId;
  
  return (
    <div className={styles.container}>
      <div className={`${styles.postCard} glass`}>
        <div className={styles.postHeader}>
          <div className={styles.avatar}></div>
          <div className={styles.userInfo}>
            <div className={styles.name}>User Name</div>
            <div className={styles.username}>@username</div>
          </div>
        </div>
        <div className={styles.postMedia}>
          {/* Mock image placeholder */}
        </div>
        <div className={styles.postContent}>
          <p className={styles.caption}>
            This is a preview of a KnockPost shared via the web. Download the app to view the full resolution media, read all comments, and join the conversation!
          </p>
        </div>
        <button className={styles.downloadBtn}>Open in KnockPost App</button>
      </div>
    </div>
  );
}
