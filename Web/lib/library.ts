export type Folder = {
  id: string;
  name: string;
  sortIndex: number;
  createdAt: string;
  modifiedAt: string;
  favoriteAt: string | null;
  trashedAt: string | null;
  colorHex: string | null;
  symbolName: string | null;
  parentId: string | null;
};

export type Card = {
  id: string;
  front: string;
  back: string;
  sortIndex: number;
};

export type LibraryItem = {
  id: string;
  title: string;
  kind: "note" | "deck";
  sortIndex: number;
  noteMarkdown: string;
  createdAt: string;
  modifiedAt: string;
  favoriteAt: string | null;
  trashedAt: string | null;
  tags: string[];
  linkedDeckId: string | null;
  folderId: string | null;
  cards: Card[];
};

export type LibrarySnapshot = {
  schemaVersion: 1;
  folders: Folder[];
  items: LibraryItem[];
};

export const emptyLibrary = (): LibrarySnapshot => ({
  schemaVersion: 1,
  folders: [],
  items: [],
});

export function isLibrarySnapshot(value: unknown): value is LibrarySnapshot {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<LibrarySnapshot>;
  return candidate.schemaVersion === 1 && Array.isArray(candidate.folders) && Array.isArray(candidate.items);
}
