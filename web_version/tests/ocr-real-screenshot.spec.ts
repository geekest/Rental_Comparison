import { expect, test } from "@playwright/test";

test("真实中文截图在本地 OCR，失败时仍可手动填写", async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto("/");
  await page.getByRole("button", { name: "我知道了，开始整理" }).click();
  await page.getByRole("button", { name: "添加房源" }).click();

  await page.locator('input[type="file"]').setInputFiles("../docs/design/references/candidate-gallery.png");
  await expect(page.getByText(/识别完成，请确认建议|未能识别，截图已绑定，请手动填写/)).toBeVisible({
    timeout: 110_000,
  });
  await expect(page.getByText("已绑定截图")).toBeVisible();

  await page.getByPlaceholder("例如：徐汇 · 一室一厅").fill("截图降级测试");
  await page.getByLabel("月租 *").fill("7800");
  await expect(page.getByRole("button", { name: "保存租赁方案" })).toBeEnabled();
});
