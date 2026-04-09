export const siteConfig = {
  name: "ForgePush",
  description: "Push notification management for iOS — permissions, tokens, silent and visible routing.",
  github: "https://github.com/stefanprojchev/ForgePush",
  nav: {
    docs: [
      { title: "Getting Started", href: "docs/getting-started" },
      {
        title: "Libraries",
        children: [
          { title: "ForgePushPermission", href: "docs/permission" },
          { title: "ForgePushToken", href: "docs/token" },
          { title: "ForgeSilentPush", href: "docs/silent-push" },
          { title: "ForgeVisiblePush", href: "docs/visible-push" },
        ],
      },
    ],
    examples: [
      { title: "AppDelegate Setup", href: "examples/app-delegate" },
      { title: "With ForgeInject", href: "examples/with-forge-inject" },
    ],
  },
};

export const proseClasses = "prose prose-neutral dark:prose-invert prose-headings:font-semibold prose-headings:tracking-tight prose-h1:text-2xl prose-h1:mb-2 prose-h2:mt-10 prose-h2:text-lg prose-h2:border-b prose-h2:border-border/60 prose-h2:pb-2 prose-h3:text-base prose-p:text-[15px] prose-p:leading-relaxed prose-code:rounded prose-code:bg-muted prose-code:px-1.5 prose-code:py-0.5 prose-code:font-mono prose-code:text-[13px] prose-code:font-normal prose-code:before:content-none prose-code:after:content-none prose-pre:bg-transparent prose-pre:p-0 prose-a:text-orange-600 prose-a:no-underline hover:prose-a:underline dark:prose-a:text-amber-400 max-w-none";

/** Resolve a nav href to a full path including base URL */
export function resolveHref(href: string): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, "");
  return `${base}/${href}`;
}
