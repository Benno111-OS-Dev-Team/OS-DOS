
#include "dos.h"                                                        /* AN000 */
#include "fdisk.h"                                                      /* AN000 */
#include "subtype.h"                                                    /* AN000 */
#include "extern.h"                                                     /* AN000 */
#include "fdiskmsg.h"                                                   /* AN000 */

/*  */
/******************* START OF SPECIFICATIONS *******************/
/*                                                             */
/* SUBROUTINE NAME: DO_MAIN_MENU                               */
/*                                                             */
/* DESCRIPTIVE NAME: Main menu display and input routine       */
/*                                                             */
/* FUNCTION:                                                   */
/*    Displays the main FDISK menu, accepts and validates      */
/*    input from menu and passes control to requested function */
/*                                                             */
/* NOTES: The following screen is managed by this routine:     */
/*                                                             */
/*       �0000000000111111111122222222223333333333�            */
/*       �0123456789012345678901234567890123456789�            */
/*     ������������������������������������������Ĵ            */
/*     00�IBM Personal Computer                   �            */
/*     01�Fixed Disk Setup Program Version 3.30   �            */
/*     02�(C)Copyright IBM Corp. 1983,1987        �            */
/*     03�                                        �            */
/*     04�FDISK Options                           �            */
/*     05�                                        �            */
/*     06�Current Fixed Disk Drive: #             �            */
/*     07�                                        �            */
/*     08�Choose one of the following:            �            */
/*     09�                                        �            */
/*     10�    1.  Create DOS partition            �            */
/*     11�    2.  Change Active Partition         �            */
/*     12�    3.  Delete DOS Partition            �            */
/*     13�    4.  Display Partition Data          �            */
/*     14�    5.  Select Next Fixed Disk Drive    �            */
/*     15�                                        �            */
/*     16�                                        �            */
/*     17�                                        �            */
/*     18�Enter choice: [#]                       �            */
/*     19�                                        �            */
/*     20�                                        �            */
/*     21�WARNING! No partitions marked active    �            */
/*     22�                                        �            */
/*     23�Press ESC to return to DOS              �            */
/*     ��������������������������������������������            */
/*                                                             */
/* ENTRY POINTS: do_main_menu                                  */
/*      LINKAGE: do_main_menu();                               */
/*               NEAR CALL                                     */
/*                                                             */
/* INPUT: None                                                 */
/*                                                             */
/* EXIT-NORMAL: ERROR=FALSE                                    */
/*                                                             */
/* EXIT-ERROR: ERROR=TRUE                                      */
/*             GOTO internal_program_error if case statement   */
/*             failure when branching to requested function    */
/*                                                             */
/* EFFECTS: No data directly modified by this routine, but     */
/*          child routines will modify data.                   */
/*                                                             */
/* INTERNAL REFERENCES:                                        */
/*   ROUTINES:                                                 */
/*      clear_screen                                           */
/*      display                                                */
/*      get_num_input                                          */
/*      create_partition                                       */
/*      change_active_partition                                */
/*      delete_partition                                       */
/*      display_partition_information                          */
/*      find_active_partition                                  */
/*      change_drive                                           */
/*      internal_program_error                                 */
/*                                                             */
/* EXTERNAL REFERENCES:                                        */
/*   ROUTINES:                                                 */
/*                                                             */
/******************** END OF SPECIFICATIONS ********************/

/*  */
void do_main_menu()

BEGIN

char   input;
char   max_input;
unsigned    temp;
unsigned    i;


   input = c(NUL);                                                      /* AC000 */
   PercentFlag = (FLAG)FALSE;                                           /* AN000 */
   /* Intialize cur_disk indicator. It is 0 based for array usage */
   /* See if first disk readable */
   cur_disk = c(0);                                                     /* AC000 */
   if (!good_disk[0])
      BEGIN
       cur_disk++;
      END

   /* See if we have a valid combo of disk */
   if ((good_disk[0]) || ((good_disk[1]) && (number_of_drives == uc(2)))) /* AC000 */
      BEGIN
       clear_screen(u(0),u(0),u(24),u(79));                             /* AC000 */
       /* Display the copyright */
       display(menu_1);

       /* See if we couldn't access drive 1 */
       if (!good_disk[0])
          BEGIN
           insert[0] = c('1');                                          /* AC000 */
           display(error_30);
          END

       /* Display the menu every time this routine is returned to until ESC */
       input = c(NUL);                                                  /* AC000 */
       while (input !=c(ESC))                                           /* AC000 */
          BEGIN
            /* Put up most of the menu */
            display(menu_2);
            display(menu_3);
            display(menu_7);

            /* Put correct disk in current disk message */
            insert[0]=cur_disk+1+'0';
            display(menu_5);

            /* Display warning prompt if no active partitions */
            /* check to see if there is an avail partition                 */
            temp = u(0);                                                /* AC000 */
            for (i = u(0); i < u(4);i++)                                /* AC000 */
               BEGIN

                /* See if any non - zero system id bytes */
                temp = temp | part_table[cur_disk][i].sys_id ;
               END
            /* Any entry that isn't zero means */
            if (temp != u(0))                                           /* AC000 */
               BEGIN
                /* If there isn't an active partition and this is disk 1, then yell) */
                if ((!find_active_partition()) && (cur_disk == c(0)))   /* AC000 */
                   display(menu_6);
               END

            /* Get the menu input */

            /* See if more than one fixed disk */
            if (number_of_drives == uc(2))                              /* AC000 */
              BEGIN
               display(menu_4);
               max_input = c(5);                                        /* AC000 */
              END
            else     /* only 4 options */
                max_input = c(4);                                       /* AC000 */
            /* Setup default and go get input */
            input = get_num_input(c(1),max_input,input_row,input_col);  /* AC000 */
            switch(input)
              BEGIN
               case  '1': create_partition();
                          break;

               case  '2': change_active_partition();
                          break;

               case  '3': delete_partition();
                          break;

               case  '4': display_partition_information();
                          break;

               case  '5': BEGIN
                           if (number_of_drives == uc(1))               /* AC000 */
                              internal_program_error();
                           else
                              BEGIN
                               /* Swap the number */
                               if (cur_disk == c(0))                    /* AC000 */
                                  BEGIN
                                   if (good_disk[1])
                                      BEGIN
                                       cur_disk++;
                                      END
                                   else
                                      BEGIN
                                       /* Disk has error reading */
                                       insert[0] = c('2');              /* AC000 */
                                       display(error_30);
                                      END
                                  END
                               else
                                  BEGIN

                                   if (cur_disk == c(1))                /* AC000 */
                                      BEGIN
                                       if (good_disk[0])
                                          BEGIN
                                           cur_disk--;
                                          END
                                       else
                                          BEGIN
                                           /* Disk has error reading */
                                           insert[0] = c('1');          /* AC000 */
                                           display(error_30);
                                          END
                                      END
                                   else
                                      internal_program_error;
                                  END
                              END
                           break;
                         END

               case  ESC: break;  /* ESC case */

               default:   internal_program_error();
              END
          END
      END
   else
      BEGIN
       /* Can't read either drive, so quit */
       no_fatal_error = c(FALSE);                                       /* AC000 */
       display(error_2);
      END
   return;
END

