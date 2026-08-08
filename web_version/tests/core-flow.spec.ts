import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "我知道了，开始整理" }).click();
});

test("候选、比较、最终确认与撤回形成闭环", async ({ page }) => {
  await expect(page.getByTestId("candidate-screen")).toBeVisible();
  await page.locator(".bottom-nav button").nth(1).click();
  await expect(page.getByTestId("compare-screen")).toBeVisible();
  await page.getByRole("button", { name: "通勤" }).click();
  await expect(page.getByText("单程到 静安寺，支出单独显示")).toBeVisible();
  await page.getByRole("button", { name: "确认最终房源" }).click();
  await page.getByPlaceholder("为什么这套更适合我？").fill("成本与通勤在我可接受范围内");
  await page.getByRole("button", { name: "由我确认最终房源" }).click();
  await expect(page.getByText("最终选择")).toBeVisible();
  await page.getByRole("button", { name: "撤回选择并重新比较" }).click();
  await expect(page.getByTestId("compare-screen")).toBeVisible();
});

test("不用截图也允许用五字段手动保存", async ({ page }) => {
  await page.getByRole("button", { name: "添加房源" }).click();
  await page.getByPlaceholder("例如：徐汇 · 一室一厅").fill("测试房源");
  await page.getByLabel("月租 *").fill("5000");
  await page.getByRole("button", { name: "保存租赁方案" }).click();
  await expect(page.getByRole("heading", { name: "测试房源" }).first()).toBeVisible();
});

test("淘汰后可恢复到候选池", async ({ page }) => {
  await page.getByTestId("listing-card-xuhui").getByRole("button", { name: "淘汰" }).click();
  await expect(page.getByRole("heading", { name: "已淘汰" })).toBeVisible();
  await page.getByRole("button", { name: "恢复" }).click();
  await expect(page.getByTestId("listing-card-xuhui")).toBeVisible();
});

test("重点考虑可独立标记，不改变房源状态", async ({ page }) => {
  await page.getByTestId("listing-card-xuhui").getByRole("button").nth(1).click();
  await page.getByRole("button", { name: "取消重点考虑" }).click();
  await expect(page.getByRole("button", { name: "标记重点考虑" })).toBeVisible();
});
