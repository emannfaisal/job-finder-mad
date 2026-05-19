from playwright.sync_api import sync_playwright
from .base_scraper import BaseScraper

class DubizzleScraper(BaseScraper):
    def scrape(self):
        jobs = []
        # Use the exact link you provided
        target_url = "https://jobs.dubizzlelabs.com/?&location=Karachi%2C%20PK#positions"

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=False) # Keep False to see it load
            page = browser.new_page()

            print(f"Navigating to: {target_url}")
            page.goto(target_url)

            # Wait for the specific list container ('ul.positions') shown in your screenshot
            try:
                print("Waiting for 'ul.positions' to load...")
                page.wait_for_selector("ul.positions", timeout=15000)
                
                # Target the li elements with class 'position' as seen in your HTML text
                cards = page.locator("ul.positions > li.position")
                count = cards.count()
                
                if count == 0:
                    # Fallback to the other class seen in your screenshot
                    cards = page.locator("li.position-transition")
                    count = cards.count()

                print(f"Found {count} job openings.")

                for i in range(count):
                    card = cards.nth(i)
                    try:
                        # Scroll to ensure lazy-loaded content appears
                        card.scroll_into_view_if_needed()
                        
                        # Based on your text conversion:
                        # Title is in h2, Location in li.location span, Link in a
                        title = card.locator("h2").inner_text(timeout=3000)
                        location = card.locator("li.location span").inner_text(timeout=3000)
                        
                        # Link is the 'a' tag. We'll grab the href attribute.
                        relative_link = card.locator("a").first.get_attribute("href", timeout=3000)
                        full_link = f"https://jobs.dubizzlelabs.com{relative_link}" if relative_link else "N/A"

                        jobs.append({
                            "title": title.strip(),
                            "location": location.strip(),
                            "link": full_link
                        })
                        print(f"✅ Extracted: {title}")

                    except Exception as e:
                        print(f"⚠️ Skipping card {i}: {e}")
                        continue

            except Exception as e:
                print(f"❌ Critical Error: {e}")
            
            finally:
                browser.close()

        return jobs

def scrape_dubizzle_labs():
    scraper = DubizzleScraper("DubizzleLabs")
    return scraper.scrape()

if __name__ == "__main__":
    data = scrape_dubizzle_labs()
    print(f"\nDone! Total scraped: {len(data)}")