import { expect, test } from "@playwright/test";

test("以 393 × 852 内容视口保存候选页和比较页", async ({ page }) => {
  await page.setViewportSize({ width: 1400, height: 1100 });
  await page.goto("/");
  const privacyButton = page.getByRole("button", { name: "我知道了，开始整理" });
  if (await privacyButton.isVisible()) await privacyButton.click();

  const deviceScreen = page.getByTestId("device-screen");
  await expect(deviceScreen).toBeVisible();
  const box = await deviceScreen.boundingBox();
  expect(Math.round(box?.width ?? 0)).toBe(393);
  expect(Math.round(box?.height ?? 0)).toBe(852);
  await deviceScreen.screenshot({ path: "artifacts/qa/candidate-393x852.png" });

  await page.locator(".bottom-nav button").nth(1).click();
  await expect(page.getByTestId("compare-screen")).toBeVisible();
  await deviceScreen.screenshot({ path: "artifacts/qa/compare-393x852.png" });
});
