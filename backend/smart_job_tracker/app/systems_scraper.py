from playwright.sync_api import sync_playwright
from .base_scraper import BaseScraper
import re

class SAPSystemsScraper(BaseScraper):
    def scrape(self):
        jobs = []
        # Using the URL visible in your screenshot
        target_url = "https://career55.sapsf.eu/career?company=systemvent&career_ns=job_listing_summary&navBarLevel=JOB_SEARCH"

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            context = browser.new_context()
            page = context.new_page()

            print(f"Navigating to SAP Portal...")
            page.goto(target_url)

            # Wait for the table rows to load
            try:
                page.select_option("select[id^='46:']", value="50") 
                page.wait_for_timeout(2000) # Wait for list to reload
                page.wait_for_selector("tr.jobResultItem", timeout=15000)
                
                # Target all job rows
                rows = page.locator("tr.jobResultItem")
                count = rows.count()
                print(f"Found {count} job results.")

                for i in range(count):
                    row = rows.nth(i)
                    try:
                        # 1. Title and Link extraction
                        title_link = row.locator("a.jobTitle")
                        title = title_link.inner_text().strip()
                        
                        # 2. Extracting Cities using a Partial ID Match
                        # This looks for any span where the ID ends with '_mfield2'
                        city_span = row.locator("span[id$='_mfield2']") 
                        
                        cities = "N/A"
                        
                        # Check if the element actually exists before trying to get attributes
                        if city_span.count() > 0:
                            onclick_value = city_span.get_attribute("onclick")
                            
                            if onclick_value:
                                # Look for the data inside the square brackets [...]
                                match = re.search(r'\[(.*?)\]', onclick_value)
                                if match:
                                    # Clean up quotes and brackets
                                    cities = match.group(1).replace('"', '').replace("'", "").strip()
                                else:
                                    # Fallback: If no brackets, just grab the visible text (e.g., "Karachi")
                                    cities = city_span.inner_text().strip()

                        jobs.append({
                            "title": title,
                            "location": cities,
                            "link": f"https://career55.sapsf.eu{title_link.get_attribute('href')}"
                        })
                        print(f"✅ Scraped: {title} | Location: {cities}")

                    except Exception as e:
                        print(f"Skipping row {i} due to: {e}")
                        continue

            except Exception as e:
                print(f"❌ Error: {e}")
            
            finally:
                browser.close()

        return jobs

def scrape_sap_portal():
    scraper = SAPSystemsScraper("SAPSystems")
    return scraper.scrape()

if __name__ == "__main__":
    results = scrape_sap_portal()
    print(f"\nTotal Captured: {len(results)}")
    for j in results[:5]:  # Print first 5
        print(j)