import * as React from 'react';
import * as SwitchPrimitive from '@radix-ui/react-switch';
import { cn } from '@/lib/utils';

export function Switch({
  className,
  ...props
}: React.ComponentProps<typeof SwitchPrimitive.Root>) {
  return (
    <SwitchPrimitive.Root
      className={cn(
        'peer inline-flex h-[1.15rem] w-8 shrink-0 items-center rounded-full border border-transparent bg-input shadow-xs transition-all outline-none data-[state=checked]:bg-primary',
        className
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb className="block size-4 translate-x-0 rounded-full bg-background transition-transform data-[state=checked]:translate-x-[calc(100%-2px)]" />
    </SwitchPrimitive.Root>
  );
}
