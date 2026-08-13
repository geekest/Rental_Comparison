import { describe, expect, it } from "vitest";
import { parseListingText } from "./ocr";

describe("房源截图结构化建议", () => {
  it("只把可识别的房源字段映射为可编辑建议", () => {
    const suggestion = parseListingText(
      "上海徐汇区漕河泾路 88 号\n月租 ¥7800，48 平米，1 室 1 厅\n楼层 6/18 层，有电梯，租期 12 个月，押一付三\n押金 7800，中介费 3000",
    );
    expect(suggestion).toMatchObject({
      city: "上海",
      rent: 7800,
      area: 48,
      layout: "1 室 1 厅",
      floor: "6/18层",
      hasElevator: true,
      leaseMonths: 12,
      paymentCadence: "quarterly",
    });
    expect(suggestion.costs).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: "押金", amount: 7800, refundable: true }),
        expect.objectContaining({ name: "中介费", amount: 3000 }),
      ]),
    );
  });
});
