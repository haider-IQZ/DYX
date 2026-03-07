import * as React from 'react';
import * as SheetPrimitive from '@radix-ui/react-dialog';
import { XIcon } from '@/components/ui/icons';
import { cn } from '@/lib/utils';

export function Sheet(props: React.ComponentProps<typeof SheetPrimitive.Root>) {
  return <SheetPrimitive.Root data-slot="sheet" {...props} />;
}

export function SheetContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Content> & {
  side?: 'top' | 'right' | 'bottom' | 'left';
}) {
  return (
    <SheetPrimitive.Portal>
      <SheetPrimitive.Overlay className="fixed inset-0 z-50 bg-black/50" />
      <SheetPrimitive.Content
        className={cn(
          'fixed inset-y-0 right-0 z-50 flex h-full w-3/4 flex-col gap-4 border-l bg-background shadow-lg sm:max-w-sm',
          className
        )}
        {...props}
      >
        {children}
        <SheetPrimitive.Close className="absolute top-4 right-4 rounded-xs opacity-70 transition-opacity hover:opacity-100 focus:outline-hidden">
          <XIcon className="size-4" />
          <span className="sr-only">Close</span>
        </SheetPrimitive.Close>
      </SheetPrimitive.Content>
    </SheetPrimitive.Portal>
  );
}

export function SheetHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return <div className={cn('flex flex-col gap-1.5 p-4', className)} {...props} />;
}

export function SheetTitle(props: React.ComponentProps<typeof SheetPrimitive.Title>) {
  return <SheetPrimitive.Title className={cn('font-semibold text-foreground', props.className)} {...props} />;
}

export function SheetDescription(
  props: React.ComponentProps<typeof SheetPrimitive.Description>
) {
  return (
    <SheetPrimitive.Description
      className={cn('text-sm text-muted-foreground', props.className)}
      {...props}
    />
  );
}
