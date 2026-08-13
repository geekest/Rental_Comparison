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
  await page.getByText("我已知晓以上未解决项").click();
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
  await page.getByLabel("居室数 *").fill("2");
  await page.getByRole("button", { name: "保存租赁方案" }).click();
  await expect(page.getByRole("heading", { name: "测试房源" }).first()).toBeVisible();
});

test("房源卡片展示楼层、租赁居室数与通勤方式", async ({ page }) => {
  const card = page.getByTestId("listing-card-xuhui");
  await expect(card.getByText("整租 1 居")).toBeVisible();
  await expect(card.getByText("8 / 18 层")).toBeVisible();
  await expect(card.getByText("地铁 · 32 分钟")).toBeVisible();
});

test("补充多张房源照片后，卡片图片区域使用独立横滑轨道", async ({ page }) => {
  await page.getByTestId("listing-card-xuhui").getByRole("button", { name: "查看详情" }).click();
  const photoInput = page.getByTestId("bottom-sheet").locator(".upload-box input[type=file]");
  await photoInput.setInputFiles(["public/assets/listings/xuhui.png", "public/assets/listings/jingan.png"]);
  await expect(page.getByText("已保存 2 张房源照片")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("sheet-overlay")).toHaveCount(0);
  const gallery = page.getByTestId("listing-card-xuhui").locator(".listing-media-carousel");
  await expect(gallery).toBeVisible();
  await expect.poll(() => gallery.evaluate((node) => node.scrollWidth - node.clientWidth)).toBeGreaterThan(0);
  const bounds = await gallery.locator(".listing-media-image").first().boundingBox();
  if (!bounds) throw new Error("房源图片轨道未渲染");
  const startX = bounds.x + bounds.width / 2;
  const startY = bounds.y + bounds.height / 2;
  await page.mouse.move(startX, startY);
  await page.mouse.down();
  for (let step = 1; step <= 8; step += 1) {
    await page.mouse.move(startX - (120 * step) / 8, startY);
    await page.waitForTimeout(8);
  }
  await expect(gallery).toHaveAttribute("data-dragging", "true");
  await page.mouse.up();
  await expect.poll(() => gallery.evaluate((node) => node.scrollLeft)).toBeGreaterThan(0);
});

test("淘汰后可恢复到候选池", async ({ page }) => {
  await page.getByTestId("listing-card-xuhui").getByRole("button", { name: "淘汰" }).click();
  await page.getByPlaceholder("例如：通勤超过硬性上限").fill("通勤时间不合适");
  await page.getByRole("button", { name: "确认淘汰" }).click();
  await expect(page.getByRole("heading", { name: "已淘汰" })).toBeVisible();
  await page.getByRole("button", { name: "恢复" }).click();
  await expect(page.getByTestId("listing-card-xuhui")).toBeVisible();
});

test("可以创建新的空白选房任务", async ({ page }) => {
  page.on("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "任务设置" }).click();
  await page.getByRole("button", { name: "创建新的选房任务" }).click();
  await expect(page.getByRole("heading", { name: "新的选房任务" })).toBeVisible();
  await expect(page.getByText("0 套候选")).toBeVisible();
});

test("重点考虑可独立标记，不改变房源状态", async ({ page }) => {
  await page.getByTestId("listing-card-xuhui").getByRole("button").nth(1).click();
  await page.getByRole("button", { name: "取消重点考虑" }).click();
  await expect(page.getByRole("button", { name: "标记重点考虑" })).toBeVisible();
});
