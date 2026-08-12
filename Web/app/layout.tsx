import type { Metadata } from "next";
import "./globals.css";

const image = "https://flashnotes-sync.arindamt0.chatgpt.site/og.png";

export const metadata: Metadata = {
  title: { default: "Flashnotes Web", template: "%s · Flashnotes" },
  description: "Your notes and flashcards, synced across Mac and web.",
  openGraph: { title: "FlashNotes", description: "Your library. Mac and web. In sync.", images: [image] },
  twitter: { card: "summary_large_image", title: "FlashNotes", description: "Your library. Mac and web. In sync.", images: [image] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
