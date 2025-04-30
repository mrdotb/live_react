import { DualRangeSlider } from "./ui/dual-range-slider";
import { Label } from "./ui/label";
import * as React from "react";
import { useState } from "react";

function formatMilliseconds(ms: number): string {
  const seconds = Math.floor(ms / 1000) % 60;
  const minutes = Math.floor(ms / (1000 * 60)) % 60;
  const hours = Math.floor(ms / (1000 * 60 * 60));

  const parts: string[] = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (seconds > 0 || parts.length === 0) parts.push(`${seconds}s`);

  return parts.join("");
}

type DelaySliderProps = {
  label: string;
  inputName: string;
  value: [number, number];
  min: number;
  max: number;
  step: number;
};

export const DelaySlider: React.FC<DelaySliderProps> = ({
  label,
  inputName,
  value,
  min,
  max,
  step,
}) => {
  const [values, setValues] = useState<[number, number]>(value);

  const handleValueChange = (newValues: number[]) => {
    if (newValues.length === 2) {
      setValues([newValues[0], newValues[1]]);
    }
  };

  return (
    <div className="w-full flex flex-col space-y-8">
      <Label>{label}</Label>
      <DualRangeSlider
        name={inputName}
        label={(value) => <span>{formatMilliseconds(value ?? 0)}</span>}
        value={values}
        onValueChange={handleValueChange}
        min={min}
        max={max}
        step={step}
      />
    </div>
  );
};
