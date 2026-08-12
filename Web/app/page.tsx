import type { Metadata } from "next";
import FlashnotesWeb from "./FlashnotesWeb";
import { requireChatGPTUser } from "./chatgpt-auth";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Flashnotes Web",
  description: "Your notes and flashcards, synced across Mac and web.",
};

export default async function Home() {
  const user = await requireChatGPTUser("/");
  return <FlashnotesWeb displayName={user.displayName} />;
}
