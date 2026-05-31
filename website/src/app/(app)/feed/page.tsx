import GlimpsReel from "@/components/GlimpsReel";
import PostCard from "@/components/PostCard";
import SuggestionsSidebar from "@/components/SuggestionsSidebar";

export default function FeedPage() {
  const mockPosts = [
    {
      id: 1,
      username: "photography_daily",
      caption: "Caught a beautiful sunset today! 🌅 #nature #photography",
      likes: 1243,
      timeAgo: "2h",
    },
    {
      id: 2,
      username: "tech_insider",
      caption: "The new KnockPost web app is finally here and it looks incredible! 🚀",
      likes: 8902,
      timeAgo: "5h",
    },
    {
      id: 3,
      username: "travel_diaries",
      caption: "Missing the mountain views from last summer. Can't wait to go back. ⛰️",
      likes: 432,
      timeAgo: "1d",
    },
  ];

  return (
    <div style={{ flex: 1, maxWidth: "470px", width: "100%", margin: "0 auto", padding: "16px 0" }}>
      {/* Render first post */}
      {mockPosts.length > 0 && <PostCard key={mockPosts[0].id} {...mockPosts[0]} />}
      
      {/* Render Glimpses after first post */}
      <GlimpsReel />
      
      {/* Render remaining posts */}
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        {mockPosts.slice(1).map((post) => (
          <PostCard key={post.id} {...post} />
        ))}
      </div>
    </div>
  );
}
